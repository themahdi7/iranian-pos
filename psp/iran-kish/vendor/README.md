# Iran Kish vendor files (not in git)

Copy the official **PCPOS WebDll** folder here (the `.exe` / `.dll` / `config.xml`
tree, not the developer PDF).

You typically need:

- `Kiccc.PCPOS.Service.exe` and `.config`
- `TestRunWindowsService.exe` and `.config`
- `config.xml`
- `KICCCPCPOSDLLTotal.dll`
- `Kiccc.PcPos.DynamicMulti.dll`
- supporting `System.*` / `Newtonsoft.Json` / MVC HTTP DLLs
- `app/*.bat` if present

Do **not** copy PDFs, `.pdb`, or log folders.

## Import helper

```bash
./scripts/import-vendor.sh "/path/to/PCPOS30.1/WebDll"
```
