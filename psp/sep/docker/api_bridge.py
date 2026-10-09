#!/usr/bin/env python3
"""Tiny REST bridge over classic ASP.NET SignalR (SSP1126HUB) for curl-friendly POS sales."""

from __future__ import annotations

import argparse
import json
import queue
import socket
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Dict, List, Optional


HUB = "SSP1126HUB"

# SSP1126 docs Response Code table (also used by GetSystemResponse Message)
RESPONSE_MESSAGES = {
    "0": "OK / ready",
    "1": "Card was swiped (clear POS: cancel / remove card, then retry)",
    "2": "Amount below MinimumAmount",
    "3": "No connection to POS device",
    "4": "Invalid data",
    "7": "Operation not allowed",
    "9": "Invalid terminal",
    "14": "Initialization error",
    "68": "Timeout waiting for response",
    "98": "Cancelled by user",
    "99": "Timeout on POS",
}


def describe_code(code: str) -> str:
    return RESPONSE_MESSAGES.get(str(code), f"code {code}")


class SignalRClient:
    def __init__(self, base_url: str, timeout: float = 90.0):
        self.base = base_url.rstrip("/") + "/signalr"
        self.timeout = timeout
        self.token = ""
        self.conn_data = json.dumps([{"name": HUB}])
        self.events: "queue.Queue[dict]" = queue.Queue()
        self._stop = threading.Event()
        self._thread: Optional[threading.Thread] = None
        self._msg_id = ""
        self._invocation = 0

    def _get(self, url: str, timeout: Optional[float] = None) -> str:
        with urllib.request.urlopen(url, timeout=timeout or self.timeout) as resp:
            return resp.read().decode("utf-8", errors="replace")

    def _post(self, url: str, body: str) -> str:
        req = urllib.request.Request(
            url,
            data=body.encode("utf-8"),
            method="POST",
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        with urllib.request.urlopen(req, timeout=self.timeout) as resp:
            return resp.read().decode("utf-8", errors="replace")

    def start(self) -> None:
        neg = json.loads(
            self._get(
                f"{self.base}/negotiate?clientProtocol=2.1&connectionData="
                f"{urllib.parse.quote(self.conn_data)}"
            )
        )
        self.token = urllib.parse.quote(neg["ConnectionToken"])
        self._get(
            f"{self.base}/start?transport=longPolling&clientProtocol=2.1"
            f"&connectionToken={self.token}&connectionData={urllib.parse.quote(self.conn_data)}"
        )
        self._thread = threading.Thread(target=self._poll_loop, daemon=True)
        self._thread.start()
        # allow first connect poll to establish
        time.sleep(0.4)

    def close(self) -> None:
        self._stop.set()
        try:
            self._get(
                f"{self.base}/abort?transport=longPolling&clientProtocol=2.1"
                f"&connectionToken={self.token}&connectionData={urllib.parse.quote(self.conn_data)}",
                timeout=5,
            )
        except Exception:
            pass

    def _poll_loop(self) -> None:
        url = (
            f"{self.base}/connect?transport=longPolling&clientProtocol=2.1"
            f"&connectionToken={self.token}&connectionData={urllib.parse.quote(self.conn_data)}"
        )
        while not self._stop.is_set():
            try:
                body = self._get(url, timeout=60)
                if not body:
                    continue
                msg = json.loads(body)
                if "C" in msg:
                    self._msg_id = msg["C"]
                    url = (
                        f"{self.base}/poll?transport=longPolling&clientProtocol=2.1"
                        f"&connectionToken={self.token}"
                        f"&connectionData={urllib.parse.quote(self.conn_data)}"
                        f"&messageId={urllib.parse.quote(self._msg_id)}"
                    )
                for m in msg.get("M") or []:
                    self.events.put(m)
            except Exception:
                if self._stop.is_set():
                    break
                time.sleep(0.3)

    def invoke(self, method: str, args: List[Any]) -> None:
        self._invocation += 1
        payload = json.dumps({"H": HUB, "M": method, "A": args, "I": self._invocation})
        body = "data=" + urllib.parse.quote(payload)
        url = (
            f"{self.base}/send?transport=longPolling&clientProtocol=2.1"
            f"&connectionToken={self.token}&connectionData={urllib.parse.quote(self.conn_data)}"
        )
        self._post(url, body)

    def wait_event(self, name: str, timeout: float) -> Optional[dict]:
        deadline = time.time() + timeout
        while time.time() < deadline:
            remaining = max(0.05, deadline - time.time())
            try:
                m = self.events.get(timeout=remaining)
            except queue.Empty:
                return None
            if m.get("M") == name:
                return m
        return None


def tcp_open(host: str, port: int, timeout: float = 1.5) -> bool:
    s = socket.socket()
    s.settimeout(timeout)
    try:
        s.connect((host, port))
        return True
    except OSError:
        return False
    finally:
        s.close()


def do_sale(signalr_url: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    amount = str(payload.get("amount", "")).strip()
    if not amount or not amount.isdigit():
        return {"ok": False, "error": "amount must be digits (Rial)"}

    pos_ip = str(payload.get("pos_ip") or payload.get("posIp") or "").strip()
    if not pos_ip:
        return {"ok": False, "error": "pos_ip is required"}

    media_type = str(payload.get("media_type", "1"))  # 1 = network
    com_port = str(payload.get("com", "COM4"))
    account_type = str(payload.get("account_type", "0"))
    language = str(payload.get("language", "0"))
    additional = payload.get("additional", "") or ""
    reference = payload.get("reference", "") or ""
    purchase_id = payload.get("purchase_id", "") or ""
    terminal_id = payload.get("terminal_id", "") or ""
    init_timeout = float(payload.get("init_timeout", 20))
    txn_timeout = float(payload.get("txn_timeout", 120))
    # Do not open a raw TCP socket to :1197 before sale — bare connect/close
    # can confuse SEP PC-POS. Reachability is validated by Initial / txn result.

    client = SignalRClient(signalr_url, timeout=max(txn_timeout, 90))
    try:
        client.start()

        def drain() -> None:
            while True:
                try:
                    client.events.get_nowait()
                except queue.Empty:
                    break

        drain()
        # Clear any stuck POS/service session from a previous attempt
        try:
            client.invoke("Reset", [])
            time.sleep(0.4)
            drain()
        except Exception:
            pass

        sys_code = None
        for attempt in range(2):
            client.invoke(
                "Initial",
                [media_type, pos_ip, com_port, account_type, language, "0"],
            )
            sys_evt = client.wait_event("GetSystemResponse", init_timeout)
            if not sys_evt:
                return {"ok": False, "error": "timeout waiting for GetSystemResponse"}
            sys_code = str((sys_evt.get("A") or [""])[0])
            print(f"[api] Initial attempt={attempt+1} GetSystemResponse={sys_code}", flush=True)
            if sys_code == "0":
                break
            # 1 = card state / sticky session — Reset and retry once
            if sys_code in {"1", "14"} and attempt == 0:
                try:
                    client.invoke("Reset", [])
                    time.sleep(0.8)
                    drain()
                except Exception:
                    pass
                continue
            return {
                "ok": False,
                "error": f"Initial failed: {describe_code(sys_code)}",
                "systemResponse": sys_code,
            }

        client.invoke(
            "SendAmount1Step",
            [amount, None, additional, reference, purchase_id, terminal_id],
        )
        txn = client.wait_event("GetTransactionResponse", txn_timeout)
        if not txn:
            return {
                "ok": False,
                "error": "timeout waiting for GetTransactionResponse (card/cancel/POS)",
                "systemResponse": "0",
            }

        args = txn.get("A") or []
        # TerminalId, ResponseCode, SerialId, RRN, ResponseDescription, TxnDate, Amount, CardNumberMask
        while len(args) < 8:
            args.append(None)
        response_code = str(args[1])
        return {
            "ok": response_code == "0",
            "terminalId": args[0],
            "responseCode": response_code,
            "responseMessage": describe_code(response_code),
            "serialId": args[2],
            "rrn": args[3],
            "responseDescription": args[4],
            "txnDate": args[5],
            "amount": args[6],
            "cardNumberMask": args[7],
            "systemResponse": "0",
        }
    except urllib.error.URLError as exc:
        return {"ok": False, "error": f"signalr unreachable: {exc}"}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}
    finally:
        try:
            client.invoke("Reset", [])
        except Exception:
            pass
        client.close()


def make_handler(signalr_url: str, default_pos: str):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt: str, *args: Any) -> None:
            print("[api] " + (fmt % args), flush=True)

        def _json(self, code: int, obj: Dict[str, Any]) -> None:
            raw = json.dumps(obj, ensure_ascii=False).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        def do_GET(self) -> None:  # noqa: N802
            path = urllib.parse.urlparse(self.path).path
            if path == "/health":
                sig_ok = tcp_open("127.0.0.1", urllib.parse.urlparse(signalr_url).port or 8080)
                self._json(
                    200 if sig_ok else 503,
                    {
                        "ok": sig_ok,
                        "signalr": signalr_url,
                        "defaultPosIp": default_pos,
                    },
                )
                return
            if path == "/pos-check":
                qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
                ip = (qs.get("ip") or [default_pos])[0]
                open1197 = tcp_open(ip, 1197)
                self._json(
                    200,
                    {"ok": open1197, "pos_ip": ip, "port": 1197, "open": open1197},
                )
                return
            self._json(404, {"ok": False, "error": "not found"})

        def do_POST(self) -> None:  # noqa: N802
            path = urllib.parse.urlparse(self.path).path
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length) if length else b"{}"
            try:
                payload = json.loads(body.decode("utf-8") or "{}")
            except json.JSONDecodeError:
                self._json(400, {"ok": False, "error": "invalid json"})
                return

            if path == "/sale":
                if not payload.get("pos_ip") and not payload.get("posIp"):
                    payload["pos_ip"] = default_pos
                result = do_sale(signalr_url, payload)
                self._json(200 if result.get("ok") or "responseCode" in result else 502, result)
                return

            if path == "/reset":
                client = SignalRClient(signalr_url, timeout=20)
                try:
                    client.start()
                    client.invoke("Reset", [])
                    self._json(200, {"ok": True})
                except Exception as exc:
                    self._json(502, {"ok": False, "error": str(exc)})
                finally:
                    client.close()
                return

            self._json(404, {"ok": False, "error": "not found"})

    return Handler


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--listen", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=8090)
    ap.add_argument("--signalr", default="http://127.0.0.1:8080")
    ap.add_argument("--default-pos", default="192.168.1.100")
    args = ap.parse_args()

    httpd = ThreadingHTTPServer(
        (args.listen, args.port), make_handler(args.signalr, args.default_pos)
    )
    print(
        f"REST bridge on http://{args.listen}:{args.port} -> {args.signalr}",
        flush=True,
    )
    httpd.serve_forever()


if __name__ == "__main__":
    main()
