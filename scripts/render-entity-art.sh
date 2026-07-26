#!/usr/bin/env bash
# Regenerate all Cindra entity/building art (icons + in-world sprites) from
# the deterministic procedural generator. Same seed -> same bytes every run.
#
#   ./scripts/render-entity-art.sh
#
# Pulls numpy+pillow through nix so the pipeline is self-contained (no global
# python needed). Writes into mods/cindra/graphics/{icons,entity}. See
# mods/cindra/graphics/ART-MANIFEST.md for the asset -> building -> track map.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
GFX="$ROOT/mods/cindra/graphics"

echo "== generating Cindra entity art (icons + sprites) =="
nix-shell -p "python3.withPackages(ps: with ps; [numpy pillow])" \
  --run "python3 scripts/gen-entity-art.py '$GFX'"

echo "== done. assets under $GFX =="
