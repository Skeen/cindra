#!/usr/bin/env bash
# Regenerate the animated working-light layers for Cindra's flare-storage
# buildings (ci-z94). Same code -> same bytes every run (the generator is purely
# analytic: no RNG, no filters).
#
#   ./scripts/render-entity-anim.sh
#
# Pulls numpy+pillow through nix so the pipeline is self-contained (no global
# python needed). Each glow strip is painted in the ROOF space of the idle body
# it sits on and hard-masked to that body's silhouette; see
# scripts/gen-entity-anim.py for the model and
# mods/cindra/graphics/ART-MANIFEST.md for the asset map.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

echo "== generating Cindra animated working-light layers =="
nix-shell -p "python3.withPackages(ps: with ps; [numpy pillow])" \
  --run "python3 scripts/gen-entity-anim.py '$ROOT'"

echo "== done. verify with: npm run test:unit:py =="
