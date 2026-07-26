#!/usr/bin/env bash
# Regenerate all Cindra planet art from procedural noise.
#
#   1. gen-planet-maps.py -> 2048x1024 equirectangular maps (graphics/space/)
#      These feed the ENGINE's live orbital render (platform_surface_render_parameters).
#   2. bake-starmap.py (Blender) -> a lit sphere baked from those same maps,
#      presenting the fixed tidally-locked fire/ice face.
#   3. downscale to the static star-map sprite (512) + a mipmapped icon (120x64).
#
# Deterministic: same noise seed in gen-planet-maps.py -> same art every run.
# All external tools are pulled through nix so the pipeline is self-contained.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
SPACE="$ROOT/mods/cindra/graphics/space"
ICONS="$ROOT/mods/cindra/graphics/icons"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$ICONS"

echo "== 1/3 generating equirectangular maps =="
nix-shell -p "python3.withPackages(ps: with ps; [numpy pillow])" \
  --run "python3 scripts/gen-planet-maps.py '$SPACE'"

echo "== 2/3 baking star-map sphere (Blender/Cycles) =="
nix shell nixpkgs#blender -c blender -b -P scripts/bake-starmap.py -- \
  "$SPACE" "$TMP/starmap-1024.png"

echo "== 3/3 downscaling sprite + building icon mip strip =="
nix shell nixpkgs#imagemagick -c bash -c '
  set -e
  src="$1"; icons="$2"
  # Static star-map sprite: 512x512 (vanilla starmap_icon_size). 8-bit RGBA.
  magick "$src" -resize 512x512 -depth 8 "$icons/starmap-planet-cindra.png"
  # Icon: mipmapped 120x64 strip (icon_size=64, icon_mipmaps=4), each mip
  # top-left in its column exactly as Factorio expects. 8-bit RGBA.
  magick -size 120x64 xc:none \
    \( "$src" -resize 64x64 \) -geometry +0+0  -composite \
    \( "$src" -resize 32x32 \) -geometry +64+0 -composite \
    \( "$src" -resize 16x16 \) -geometry +96+0 -composite \
    \( "$src" -resize 8x8   \) -geometry +112+0 -composite \
    -depth 8 "$icons/cindra.png"
' _ "$TMP/starmap-1024.png" "$ICONS"

echo "done:"
echo "  $ICONS/starmap-planet-cindra.png"
echo "  $ICONS/cindra.png"
echo "  $SPACE/ (equirectangular maps for the orbital backdrop)"
