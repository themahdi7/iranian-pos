#!/usr/bin/env bash
set -euo pipefail
SRC="${1:-}"
DEST="$(cd "$(dirname "$0")/.." && pwd)/vendor"
if [[ -z "$SRC" || ! -d "$SRC" ]]; then
  echo "Usage: $0 /path/to/SSP1126/Install" >&2
  exit 1
fi
if [[ ! -f "$SRC/SSP1126SignalRWindowsService.exe" ]]; then
  echo "No SSP1126SignalRWindowsService.exe in $SRC" >&2
  exit 1
fi
mkdir -p "$DEST"
cp -f "$SRC"/*.exe "$SRC"/*.dll "$SRC"/*.config "$DEST/"
# Strip debug / install junk if copied by glob
rm -f "$DEST"/*.pdb "$DEST"/*.xml "$DEST"/*.log "$DEST"/*.InstallState "$DEST"/*.bat
echo "Copied vendor files to $DEST"
ls -1 "$DEST" | grep -v README | grep -v gitkeep
