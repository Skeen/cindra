#!/usr/bin/env bash
# Capture ACTUAL in-engine screenshots of Cindra's live GROUND (ci-tizx), so a
# worldgen decal/terrain density change can be judged the way the player sees it.
# The factorio-test harness runs HEADLESS (game.take_screenshot is a silent no-op
# there), so this drives the full CLIENT under Xvfb with software GL via EGL --
# the ci-036 / ci-ijk / ci-6y9 incantation. Factorio's bundled sdl2-compat honours
# SDL_VIDEO_FORCE_EGL, so we get a GL context without a working GLX.
#
# Output PNGs land in $WRITE_DATA/script-output/ (mapgen-cold-half.png plus the
# three closeups), produced by mods/cindra/scenarios/mapgen-shot/control.lua.
#
# Usage: scripts/render-mapgen.sh           # runs a couple of minutes then exits
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

# Same install discovery as play.sh / the integration runner: FACTORIO_PATH,
# FACTORIO_DIR, the in-repo ./factorio, then factorio-patched/ or factorio/ in
# any parent directory. The resolver fails loudly and non-zero on its own when
# there is no engine, so an in-engine render can never be quietly skipped.
FACTORIO_BIN="$(scripts/resolve-factorio.sh "$ROOT")" || exit 1

# --- resolve software-GL stack from nix (mesa/llvmpipe + glvnd + Xvfb) --------
echo "== resolving GL stack ==" >&2
MESA="$(nix build --no-link --print-out-paths nixpkgs#mesa | head -1)"
GLVND="$(nix build --no-link --print-out-paths nixpkgs#libglvnd | head -1)"
XVFB="$(nix build --no-link --print-out-paths nixpkgs#xorg.xvfb | head -1)"

# --- scratch write-data dir + mod bundle (cindra + env-scanner, NO f-test) ----
WRITE_DATA="$ROOT/.mapgen-render"
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

# --- headless X + software EGL ------------------------------------------------
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
  --load-scenario cindra/mapgen-shot \
  >"$WRITE_DATA/factorio.log" 2>&1 &
FACT_PID=$!

# Wait for the screenshots (or time out). control.lua fires at tick 60 and the
# PNG flush completes within a couple of seconds; give it generous headroom.
# Asset load under llvmpipe is slow (~30s of mipmap generation) before the
# scenario even starts, so give it a generous budget and break as soon as the
# last screenshot lands.
for i in $(seq 1 180); do
  if [ -f "$WRITE_DATA/script-output/mapgen-deep-frost.png" ]; then
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
