#!/usr/bin/env bash
# Regenerate the CREATED frozen layers (frost patches) for Cindra buildings whose
# bespoke art ships none (ci-u92y). Same code + seed -> same bytes every run.
#
#   ./scripts/render-frost-layer.sh
#
# Pulls numpy+pillow through nix so the pipeline is self-contained (no global
# python needed). Each patch is DERIVED from the body sprite it will be drawn
# over, so it registers on the real shapes; see scripts/gen-frost-layer.py for
# the accretion model and mods/cindra/graphics/ART-MANIFEST.md for the asset map.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

echo "== generating Cindra frozen layers (frost patches) =="
nix-shell -p "python3.withPackages(ps: with ps; [numpy pillow])" \
  --run "python3 scripts/gen-frost-layer.py '$ROOT'"

echo "== done. verify with: npm run test:unit:py =="
