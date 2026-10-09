#!/usr/bin/env bash
set -euo pipefail
SRC="${1:-}"
DEST="$(cd "$(dirname "$0")/.." && pwd)/vendor"
if [[ -z "$SRC" || ! -d "$SRC" ]]; then
  echo "Usage: $0 /path/to/PCPOS/WebDll" >&2
  exit 1
fi
if [[ ! -f "$SRC/Kiccc.PCPOS.Service.exe" ]]; then
  echo "No Kiccc.PCPOS.Service.exe in $SRC" >&2
  exit 1
fi
mkdir -p "$DEST/app"
cp -f "$SRC"/*.exe "$SRC"/*.dll "$SRC"/*.config "$SRC"/config.xml "$DEST/" 2>/dev/null || true
if [[ -d "$SRC/app" ]]; then
  cp -f "$SRC/app"/*.bat "$DEST/app/" 2>/dev/null || true
fi
rm -f "$DEST"/*.pdb "$DEST"/*.xml
# keep config.xml
[[ -f "$SRC/config.xml" ]] && cp -f "$SRC/config.xml" "$DEST/"
echo "Copied vendor files to $DEST"
ls -1 "$DEST" | grep -v README | grep -v gitkeep
