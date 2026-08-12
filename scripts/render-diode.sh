#!/usr/bin/env bash
# Capture ACTUAL in-engine screenshots of the placed power diode (ci-ntgh).
# The factorio-test harness runs HEADLESS (game.take_screenshot is a silent no-op
# there) and LuaEntityPrototype exposes no graphics accessors, so this drives the
# full CLIENT under Xvfb with software GL via EGL -- the same incantation as
# scripts/render-orbit.sh. Factorio's bundled sdl2-compat honours
# SDL_VIDEO_FORCE_EGL, so we get a GL context without a working GLX.
#
# Output PNGs land in $WRITE_DATA/script-output/ (diode-unwired/powered/overview),
# produced by mods/cindra/scenarios/diode-shot/control.lua.
#
# Usage: scripts/render-diode.sh
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

FACTORIO_BIN="${FACTORIO_PATH:-$ROOT/factorio/bin/x64/factorio}"
[ -x "$FACTORIO_BIN" ] || { echo "factorio binary not found at $FACTORIO_BIN" >&2; exit 1; }

echo "== resolving GL stack ==" >&2
MESA="$(nix build --no-link --print-out-paths nixpkgs#mesa | head -1)"
GLVND="$(nix build --no-link --print-out-paths nixpkgs#libglvnd | head -1)"
XVFB="$(nix build --no-link --print-out-paths nixpkgs#xorg.xvfb | head -1)"

WRITE_DATA="$ROOT/.diode-render"
rm -rf "$WRITE_DATA"
mkdir -p "$WRITE_DATA/script-output"

MODS="$WRITE_DATA/mods"
mkdir -p "$MODS"
ln -sfn "$ROOT/mods/cindra" "$MODS/cindra"
ln -sfn "$ROOT/mods/env-scanner" "$MODS/env-scanner"
# DLC (space-age/quality/elevated-rails/recycler) auto-load from the install's
# data/ -- do NOT symlink them or Factorio errors "Duplicate mod".
cat > "$MODS/mod-list.json" <<'JSON'
{
  "mods": [
    { "name": "cindra", "enabled": true },
    { "name": "env-scanner", "enabled": true },
    { "name": "base", "enabled": true },
    { "name": "elevated-rails", "enabled": true },
    { "name": "quality", "enabled": true },
    { "name": "recycler", "enabled": true },
    { "name": "space-age", "enabled": true }
  ]
}
JSON

cat > "$WRITE_DATA/config.ini" <<CFG
[path]
read-data=__PATH__executable__/../../data
write-data=$WRITE_DATA
CFG

export DISPLAY=:99
"$XVFB/bin/Xvfb" :99 -screen 0 1600x1000x24 >/dev/null 2>&1 &
XVFB_PID=$!
trap 'kill "$XVFB_PID" 2>/dev/null || true' EXIT
sleep 2

export LD_LIBRARY_PATH="$GLVND/lib:$MESA/lib"
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export SDL_VIDEO_FORCE_EGL=1
export __EGL_VENDOR_LIBRARY_DIRS="$MESA/share/glvnd/egl_vendor.d"

echo "== launching factorio (headless EGL) ==" >&2
"$FACTORIO_BIN" \
  --config "$WRITE_DATA/config.ini" \
  --mod-directory "$MODS" \
  --load-scenario cindra/diode-shot \
  >"$WRITE_DATA/factorio.log" 2>&1 &
FACT_PID=$!

# Asset load under llvmpipe is slow (~30s of mipmap generation) before the
# scenario even starts, so give it a generous budget and break as soon as the
# last screenshot lands.
for i in $(seq 1 240); do
  if [ -f "$WRITE_DATA/script-output/diode-overview.png" ]; then
    sleep 3  # let the last flush finish
    break
  fi
  if ! kill -0 "$FACT_PID" 2>/dev/null; then break; fi
  sleep 1
done
kill "$FACT_PID" 2>/dev/null || true
wait "$FACT_PID" 2>/dev/null || true

echo "== output ==" >&2
ls -la "$WRITE_DATA/script-output/" >&2 || true
echo "log tail:" >&2
tail -20 "$WRITE_DATA/factorio.log" >&2 || true
