# Contributing

This repo is Linux/Wine/Docker glue for official Iranian PC-POS SDKs.

## Do

- Add a new PSP under `psp/<slug>/` with its own `Dockerfile`, `compose.yaml`,
  and `vendor/README.md`.
- Reuse `runtime/wine-dotnet` instead of installing Wine again.
- Document the **vendor listen port** vs the **POS TCP port**.
- Keep host networking as the documented default when the terminal is on LAN.

## Do not

- Commit `.exe`, `.dll`, `.pdb`, PDFs, or hashed terminal IDs.
- Paste vendor manuals into this tree (link to “obtain from your PSP”).
- Open a raw TCP socket to the POS as a “health check” immediately before a
  sale on SEP — that can confuse some terminals.

## New PSP checklist

1. `psp/<name>/vendor/README.md` — which official files to copy
2. `scripts/import-vendor.sh`
3. `Dockerfile` `FROM iranian-pos-wine:latest`
4. `compose.yaml` with `network_mode: host`
5. Short README: init + send-amount flow only (no protocol dumps)
