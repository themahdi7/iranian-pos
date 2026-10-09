# iranian-pos

Run official Iranian **PC-POS Windows services on Linux** with Wine and Docker.

This is **not** a reimplementation of Shaparak/PSP protocols. It wraps the
installer you already get from the PSP so the same Windows service can listen
on Linux and talk to a LAN terminal.

| PSP | Folder | Vendor package | App port | POS TCP |
|-----|--------|----------------|----------|---------|
| **SEP / Saman** (سامان) | [`psp/sep`](psp/sep) | SSP1126 SignalR | `8080` | `1197` |
| **Iran Kish** (ایران کیش) | [`psp/iran-kish`](psp/iran-kish) | PCPOS WebDll | `9500` | `1100` |

## What this repo publishes

- Shared Wine + Wine Mono image (`runtime/wine-dotnet`)
- Docker Compose per PSP
- A tiny optional REST helper for SEP (`curl` one-shot sale)
- How-to docs for Linux

## What this repo does **not** publish

- PSP `.exe` / `.dll` installers
- PSP PDFs and developer manuals
- Your terminal IDs, merchant IDs, or `Field_*` hashes

Copy those yourself into `psp/<name>/vendor/` (gitignored). See [NOTICE](NOTICE).

**Do not open-source the vendor documentation** unless the PSP explicitly
allows it. Keep the official zip on your machine; this project only explains
how to run it on Linux.

## Quick start (SEP)

```bash
# 1. Official SSP1126 Install folder (from your PSP zip)
./psp/sep/scripts/import-vendor.sh "/path/to/ServiceInstaller_1402-06-29/Install"

# 2. POS LAN address
cp psp/sep/.env.example psp/sep/.env   # edit POS_IP=

# 3. Images
make runtime
make sep

# 4. Terminal: enable LAN / PC-POS (port 1197)
curl -sS http://127.0.0.1:8090/health
./psp/sep/examples/sale.sh 10000
```

Native API is still SignalR hub `SSP1126HUB` on port **8080**. Port **8090** is
only a convenience wrapper.

Full notes: [`psp/sep/README.md`](psp/sep/README.md) · architecture: [`docs/architecture.md`](docs/architecture.md)

## Rules that matter on Linux

1. **Host network** — the container must reach `POS_IP:1197` / `:1100` on your LAN.
2. **One stack at a time** — local Wine and Docker both bind `8080`/`9500`.
3. **PC-POS mode on the device** — ICMP ping is not enough; the POS TCP port must be open.
4. **wine32** is required for 32-bit .NET EXEs (the Docker image includes it).

## License

[MIT](LICENSE) for *this* glue code only. Vendor binaries stay under the PSP license.

## Adding another PSP

See [CONTRIBUTING.md](CONTRIBUTING.md). Next typical names: BehPardakht, Saman Kish
if you have a distinct SDK, Pasargad, Parsian — each needs its own `psp/<slug>/`.
