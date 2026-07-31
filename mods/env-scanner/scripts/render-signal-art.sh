#!/usr/bin/env bash
# Regenerate the environmental scanner's bespoke virtual-signal icons (ci-kuu)
# from the deterministic procedural generator. Same code -> same bytes every run.
#
#   mods/env-scanner/scripts/render-signal-art.sh
#
# Pulls numpy+pillow through nix so the pipeline is self-contained (no global
# python needed). Writes into mods/env-scanner/graphics/icons/signals/. These
# are self-authored (own work, nothing to attribute); see CREDITS.md.
set -euo pipefail

cd "$(dirname "$0")/.."          # mods/env-scanner
ROOT="$PWD"
GFX="$ROOT/graphics"

echo "== generating env-scanner signal icons =="
nix-shell -p "python3.withPackages(ps: with ps; [numpy pillow])" \
  --run "python3 scripts/gen-signal-art.py '$GFX'"

echo "== done. signal icons under $GFX/icons/signals =="
