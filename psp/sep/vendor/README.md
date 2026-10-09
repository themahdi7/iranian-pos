# SEP / Saman vendor files (not in git)

Copy the official **SSP1126 Web Based (SignalR)** installer files here.

From the PSP zip, use the `ServiceInstaller_*/Install/` folder. You need at least:

- `SSP1126SignalRWindowsService.exe`
- `SSP1126SignalRWindowsService.exe.config`
- `SSP1126.PcPos.dll`
- `Sep.Logger.dll`
- `log4net.dll`
- `Owin.dll`
- `Newtonsoft.Json.dll`
- `Microsoft.AspNet.SignalR.Core.dll`
- `Microsoft.Owin.dll`
- `Microsoft.Owin.Cors.dll`
- `Microsoft.Owin.Diagnostics.dll`
- `Microsoft.Owin.Host.HttpListener.dll`
- `Microsoft.Owin.Hosting.dll`
- `Microsoft.Owin.Security.dll`
- `System.Web.Cors.dll`

Do **not** copy PDFs, `.pdb`, install logs, or `InstallUtil` logs.

## Import helper

```bash
./scripts/import-vendor.sh "/path/to/ServiceInstaller_1402-06-29/Install"
```

Then:

```bash
# from repo root
make runtime
make sep
```
