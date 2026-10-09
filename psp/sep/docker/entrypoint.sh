#!/usr/bin/env bash
set -euo pipefail

export WINEARCH="${WINEARCH:-win64}"
export WINEPREFIX="${WINEPREFIX:-/wine}"
export WINEDEBUG="${WINEDEBUG:--all}"
export DISPLAY="${DISPLAY:-:99}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-winemenubuilder.exe=d}"

SIGNALR_PORT="${SSP_SIGNALR_PORT:-8080}"
API_PORT="${SSP_API_PORT:-8090}"
POS_IP="${SSP_POS_IP:-192.168.1.100}"
HOST_URL="${SSP_HOST_URL:-http://127.0.0.1:${SIGNALR_PORT}}"
APP_DIR="/app/Install"
BIN='C:\SSP1126\SSP1126SignalRWindowsService.exe'
SVC="SSP1126Service1"

mkdir -p /tmp/.X11-unix
if ! pgrep -x Xvfb >/dev/null 2>&1; then
  Xvfb "$DISPLAY" -screen 0 1024x768x24 -ac +extension GLX +render -noreset >/tmp/xvfb.log 2>&1 &
  sleep 0.5
fi

python3 - <<'PY'
from pathlib import Path
import os, re

src = Path("/app/Install/SSP1126SignalRWindowsService.exe.config")
text = src.read_text(encoding="utf-8")
host = os.environ.get("SSP_HOST_URL", "http://127.0.0.1:8080")
pos = os.environ.get("SSP_POS_IP", "192.168.1.100")
log_path = r"C:\Log\\"

def set_key(xml: str, key: str, value: str) -> str:
    return re.sub(
        rf'(key="{re.escape(key)}"\s+value=")[^"]*"',
        lambda m: m.group(1) + value + '"',
        xml,
        count=1,
    )

text = set_key(text, "HostUrl", host)
text = set_key(text, "PosIP", pos)
text = set_key(text, "LogPath", log_path)
src.write_text(text, encoding="utf-8")
print(f"Config HostUrl={host} PosIP={pos}")
PY

if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
  echo "Initializing Wine prefix..."
  timeout 90 wineboot -u >/tmp/wineboot.log 2>&1 || true
  wineserver -w || true
fi

WINE_WINDOWS="$WINEPREFIX/drive_c/windows"
MONO_VER="wine-mono-10.4.1"
MONO_LIB="/usr/share/wine/mono/${MONO_VER}/lib/mono"
mkdir -p "$WINEPREFIX/drive_c/windows/mono"
if [[ ! -d "$WINEPREFIX/drive_c/windows/mono/${MONO_VER}" && -d "/usr/share/wine/mono/${MONO_VER}" ]]; then
  cp -a "/usr/share/wine/mono/${MONO_VER}" "$WINEPREFIX/drive_c/windows/mono/${MONO_VER}"
fi

for ver in v2.0.50727 v4.0.30319; do
  for arch in Framework Framework64; do
    dir="$WINE_WINDOWS/Microsoft.NET/$arch/$ver"
    mkdir -p "$dir"
    if [[ ! -e "$dir/mscorlib.dll" ]]; then
      if [[ "$ver" == v2.0.50727 && -f "$MONO_LIB/2.0-api/mscorlib.dll" ]]; then
        cp "$MONO_LIB/2.0-api/mscorlib.dll" "$dir/mscorlib.dll"
      elif [[ -f "$MONO_LIB/4.5/mscorlib.dll" ]]; then
        cp "$MONO_LIB/4.5/mscorlib.dll" "$dir/mscorlib.dll"
      fi
    fi
    : > "$dir/mscorwks.dll"
    : > "$dir/InstallUtil.exe"
  done
done

wine reg add "HKLM\\Software\\Microsoft\\NET Framework Setup\\NDP\\v2.0.50727" /f /v Install /t REG_DWORD /d 1 >/dev/null
wine reg add "HKLM\\Software\\Microsoft\\NET Framework Setup\\NDP\\v2.0.50727" /f /v Version /t REG_SZ /d "2.0.50727.4927" >/dev/null
wine reg add "HKLM\\Software\\Microsoft\\NET Framework Setup\\NDP\\v4.0\\Full" /f /v Install /t REG_DWORD /d 1 >/dev/null
wine reg add "HKLM\\Software\\Microsoft\\NET Framework Setup\\NDP\\v4.0\\Full" /f /v Version /t REG_SZ /d "4.5.50709" >/dev/null
wine reg add "HKLM\\Software\\Microsoft\\.NETFramework" /f /v InstallRoot /t REG_SZ /d "C:\\windows\\Microsoft.NET\\Framework\\" >/dev/null

mkdir -p "$WINEPREFIX/drive_c/Log" "$WINEPREFIX/drive_c/SSP1126"
cp -f "$APP_DIR"/*.exe "$APP_DIR"/*.dll "$APP_DIR"/*.config "$WINEPREFIX/drive_c/SSP1126/"

wine cmd /c "ping -n 100000 127.0.0.1 >nul" >/tmp/ssp-keepalive.log 2>&1 &
KEEP_PID=$!
sleep 1

if ! wine sc query "$SVC" >/dev/null 2>&1; then
  echo "Creating $SVC..."
  wine sc create "$SVC" start= demand binpath= "$BIN" || true
fi

echo "Starting $SVC (SignalR on ${HOST_URL})..."
wine net start "$SVC" >/tmp/ssp-netstart.log 2>&1 || true

port_open() {
  python3 - "$1" <<'PY'
import socket, sys
port = int(sys.argv[1])
s = socket.socket()
s.settimeout(1)
try:
    s.connect(("127.0.0.1", port))
except OSError:
    sys.exit(1)
finally:
    s.close()
PY
}

ok=0
for _ in $(seq 1 80); do
  if port_open "$SIGNALR_PORT"; then
    ok=1
    break
  fi
  if ! wine sc query "$SVC" 2>/dev/null | grep -q RUNNING; then
    wine net start "$SVC" >/tmp/ssp-netstart.log 2>&1 || true
  fi
  sleep 0.5
done

if [[ "$ok" -ne 1 ]]; then
  echo "SignalR did not listen on ${SIGNALR_PORT}" >&2
  wine sc query "$SVC" || true
  tail -n 80 /tmp/wineboot.log /tmp/xvfb.log /tmp/ssp-netstart.log /tmp/ssp-keepalive.log 2>/dev/null || true
  exit 1
fi

echo "SignalR hubs: ${HOST_URL}/signalr/hubs"
echo "REST helper : http://127.0.0.1:${API_PORT}/sale"

python3 /app/api_bridge.py \
  --listen "0.0.0.0" \
  --port "$API_PORT" \
  --signalr "$HOST_URL" \
  --default-pos "$POS_IP" \
  >/tmp/ssp-api.log 2>&1 &

for _ in $(seq 1 40); do
  if curl -fsS "http://127.0.0.1:${API_PORT}/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

echo "SEP SSP1126 ready."
wait "$KEEP_PID"
