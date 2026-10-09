#!/usr/bin/env bash
set -euo pipefail

export WINEARCH="${WINEARCH:-win64}"
export WINEPREFIX="${WINEPREFIX:-/wine}"
export WINEDEBUG="${WINEDEBUG:--all}"
export DISPLAY="${DISPLAY:-:99}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-winemenubuilder.exe=d}"

PORT="${PCPOS_PORT:-9500}"
APP_DIR="/app/WebDll"
BIN="Z:\\app\\WebDll\\Kiccc.PCPOS.Service.exe"

mkdir -p /tmp/.X11-unix
if ! pgrep -x Xvfb >/dev/null 2>&1; then
  Xvfb "$DISPLAY" -screen 0 1024x768x24 -ac +extension GLX +render -noreset >/tmp/xvfb.log 2>&1 &
  sleep 0.5
fi

python3 - <<PY
from pathlib import Path
import os, re
port = os.environ.get("PCPOS_PORT", "9500")
p = Path("/app/WebDll/config.xml")
text = p.read_text(encoding="utf-8")
text = re.sub(r"<Port>.*?</Port>", f"<Port>{port}</Port>", text, count=1)
p.write_text(text, encoding="utf-8")
PY

if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
  echo "Initializing Wine prefix..."
  timeout 60 wineboot -u >/tmp/wineboot.log 2>&1 || true
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
wine reg add "HKLM\\Software\\Microsoft\\NET Framework Setup\\NDP\\v2.0.50727" /f /v InstallPath /t REG_SZ /d "C:\\windows\\Microsoft.NET\\Framework\\v2.0.50727\\" >/dev/null
wine reg add "HKLM\\Software\\Microsoft\\.NETFramework" /f /v InstallRoot /t REG_SZ /d "C:\\windows\\Microsoft.NET\\Framework\\" >/dev/null

cp -f "$APP_DIR/config.xml" "$WINEPREFIX/drive_c/config.xml"
cp -f "$APP_DIR/config.xml" "$WINE_WINDOWS/system32/config.xml"

cd "$APP_DIR"
mkdir -p "$WINEPREFIX/drive_c/app"
cp -f "$APP_DIR"/app/*.bat "$WINEPREFIX/drive_c/app/" 2>/dev/null || true

if ! wine sc query Kiccc.PCPOS.Service >/dev/null 2>&1; then
  echo "Creating Kiccc.PCPOS.Service..."
  wine sc create Kiccc.PCPOS.Service start= auto binpath= "$BIN" || true
fi

echo "Starting PCPOS helper..."
wine TestRunWindowsService.exe >/tmp/helper.log 2>&1 &
HELPER_PID=$!

for _ in $(seq 1 40); do
  if pgrep -f 'TestRunWindowsService.exe' >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

echo "Starting Kiccc.PCPOS.Service on port $PORT..."
wine net start Kiccc.PCPOS.Service || true

port_open() {
  python3 - "$PORT" <<'PY'
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
  if port_open; then
    ok=1
    break
  fi
  sleep 0.5
done

if [[ "$ok" -ne 1 ]]; then
  echo "PCPOS REST did not listen on $PORT" >&2
  wine sc query Kiccc.PCPOS.Service || true
  tail -n 50 /tmp/wineboot.log /tmp/xvfb.log /tmp/helper.log 2>/dev/null || true
  exit 1
fi

echo "PCPOS REST is up at http://127.0.0.1:$PORT/GeneralServiceHost"
wait "$HELPER_PID"
