# Iran Kish (ایران کیش) — PCPOS on Linux

Official package: **PCPOS** (`Kiccc.PCPOS.Service`).  
Terminal PC-POS port is typically **TCP 1100**. The Windows service listens on
**9500** (`/GeneralServiceHost`) by default in this setup.

```
Your app  →  http://127.0.0.1:9500/GeneralServiceHost
          →  Wine Windows service
          →  POS 192.168.x.x:1100
```

## 1. Drop in the official WebDll

```bash
./scripts/import-vendor.sh "/path/to/PCPOS30.1/WebDll"
```

See [vendor/README.md](vendor/README.md). Do not commit those files.

## 2. Build

From the **repository root**:

```bash
make runtime
make iran-kish
```

Use **host networking** so the container can reach the POS on the LAN.

## 3. Call the vendor REST API

The service is the official `GeneralServiceHost` (Initiate + Sale). Use the
HTML tester that ships with the PSP package, or POST to the same paths your
Windows integration already uses.

Do not run this container together with a host Wine PCPOS on port 9500.
