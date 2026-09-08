#!/usr/bin/env bash
# Exports STARBYTE to web/ using the "Web" preset in export_presets.cfg.
# Set GODOT to your Godot 4.7 binary if it is not on PATH, e.g.
#   GODOT="/Applications/Godot.app/Contents/MacOS/Godot" ./export_web.sh
set -euo pipefail

GODOT="${GODOT:-godot}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/web"

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "Godot not found. Set GODOT to the binary, for example:" >&2
  echo '  GODOT="/Applications/Godot.app/Contents/MacOS/Godot" ./export_web.sh' >&2
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"
# keep Godot from importing the export output back into the project
: > "$OUT/.gdignore"

# --import first so a clean checkout has its .godot cache before exporting
"$GODOT" --headless --path "$HERE" --import
"$GODOT" --headless --path "$HERE" --export-release "Web" "$OUT/index.html"

# Godot always writes the same index.js / index.wasm / index.pck names, so a
# returning browser can serve a stale build from cache forever. Rename the
# engine files after the content they hold and point index.html at the new
# names: a new build is a new URL, which no cache can shadow.
python3 "$HERE/tools/fingerprint_web.py" "$OUT"

echo
echo "Exported to $OUT"
ls -la "$OUT"
