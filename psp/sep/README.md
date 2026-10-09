# SEP / Saman (سامان) — SSP1126 on Linux

Official package name: **SSP1126 Web Based (SignalR)**.  
PSP: Saman Electronic Payment (SEP). Terminal PC-POS port: **TCP 1197**.

```
Your app  →  http://127.0.0.1:8080/signalr  (hub SSP1126HUB)
          →  Wine Windows service
          →  POS 192.168.x.x:1197
```

Optional REST helper (same container): `http://127.0.0.1:8090/sale`

## 1. Drop in the official installer

```bash
./scripts/import-vendor.sh "/path/to/ServiceInstaller_1402-06-29/Install"
```

See [vendor/README.md](vendor/README.md). Do not commit those files.

In `SSP1126SignalRWindowsService.exe.config`, `Field_1`…`Field_N` are **hashed
terminal IDs** for terminals allowed to talk to the service. Keep your real
config private; the sample hashes in the vendor zip are not yours.

## 2. Build the shared Wine runtime, then this image

From the **repository root**:

```bash
cp psp/sep/.env.example psp/sep/.env   # set POS_IP
make runtime
make sep
```

Or:

```bash
docker build -t iranian-pos-wine:latest runtime/wine-dotnet
cd psp/sep
docker compose -f compose.yaml up -d --build
```

Stop any local Wine process on port 8080 first.

## 3. Send an amount

Enable **LAN / PC-POS** on the terminal so `192.168.1.100:1197` accepts TCP.

```bash
curl -sS http://127.0.0.1:8090/health
./examples/sale.sh 10000
```

Native SignalR (what the vendor web tester uses):

1. `Initial("1", "<POS_IP>", "COM4", "0", "0", "0")`
2. Wait for `GetSystemResponse == "0"`
3. `SendAmount1Step(amount, null, "", "", "", "")`
4. Wait for `GetTransactionResponse`

Useful result codes: `0` paid, `68` no card in time, `98` cancelled on POS,
`3` no device, `1` stuck card state (press Cancel on the terminal).

## Ports

| Port | What |
|------|------|
| 8080 | Vendor SignalR (source of truth) |
| 8090 | Optional REST helper |
| 1197 | POS terminal (not this container) |
