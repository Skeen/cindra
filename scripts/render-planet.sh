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
#
# TOOLS. Prefer whatever is already on PATH -- inside `nix develop` that is the
# flake's PINNED python/blender/imagemagick, the same versions every clone gets.
# Only when a tool is missing do we fall back to pulling it from the ambient nix
# registry, which is NOT pinned: a different Blender there bakes a subtly
# different sprite, which is exactly the kind of drift a deterministic art
# pipeline must not have. Run this from `nix develop` for reproducible output.
set -euo pipefail

# Run "$@" with the named tool, from PATH if present, else via nix.
with_tool() {
  local tool=$1 fallback=$2
  shift 2
  if command -v "$tool" >/dev/null 2>&1; then
    "$@"
  else
    echo "note: $tool not on PATH (run inside 'nix develop' for the pinned version)" >&2
    # shellcheck disable=SC2086
    nix shell $fallback -c "$@"
  fi
}

cd "$(dirname "$0")/.."
ROOT="$PWD"
SPACE="$ROOT/mods/cindra/graphics/space"
ICONS="$ROOT/mods/cindra/graphics/icons"
MODROOT="$ROOT/mods/cindra"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$ICONS"

echo "== 1/3 generating equirectangular maps =="
if python3 -c "import numpy, PIL" >/dev/null 2>&1; then
  python3 scripts/gen-planet-maps.py "$SPACE"
else
  echo "note: python3 lacks numpy/pillow (run inside 'nix develop')" >&2
  nix-shell -p "python3.withPackages(ps: with ps; [numpy pillow])" \
    --run "python3 scripts/gen-planet-maps.py '$SPACE'"
fi

echo "== 2/3 baking star-map sphere (Blender/Cycles) =="
# Blender 5.x runs its scene compositor (our Glare bloom) on the GPU even with
# -b, and SEGFAULTS where there is no usable GL/Vulkan -- i.e. on any headless
# machine. Hand it Mesa's LAVAPIPE software Vulkan (exported by the flake dev
# shell as MESA_ICD_DIR): the bake then works headless AND is reproducible,
# since every machine composites through the same software rasteriser instead of
# whatever GPU it happens to have.
LVP=$(ls "${MESA_ICD_DIR:-/nonexistent}"/lvp_icd.*.json 2>/dev/null | head -1 || true)
GPU_ARGS=()
if [ -n "$LVP" ]; then
  export VK_DRIVER_FILES="$LVP" VK_ICD_FILENAMES="$LVP"
  GPU_ARGS=(--gpu-backend vulkan)
else
  echo "note: no lavapipe ICD (MESA_ICD_DIR unset?); Blender may crash headless" >&2
fi
with_tool blender nixpkgs#blender \
  blender -b "${GPU_ARGS[@]}" -P scripts/bake-starmap.py -- "$SPACE" "$TMP/starmap-1024.png"

echo "== 3/3 downscaling sprite + building icon mip strip + mod thumbnail =="
with_tool magick nixpkgs#imagemagick bash -c '
  set -e
  src="$1"; icons="$2"; modroot="$3"
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
  # Mod-portal thumbnail (thumbnail.png at the mod root, Factorio thumbnail spec):
  # the SAME baked globe so the portal card matches the in-game star-map planet.
  # 144x144 8-bit RGBA on the bake transparent film.
  magick "$src" -resize 144x144 -depth 8 "$modroot/thumbnail.png"
' _ "$TMP/starmap-1024.png" "$ICONS" "$MODROOT"

echo "done:"
echo "  $ICONS/starmap-planet-cindra.png"
echo "  $ICONS/cindra.png"
echo "  $MODROOT/thumbnail.png"
echo "  $SPACE/ (equirectangular maps for the orbital backdrop)"
