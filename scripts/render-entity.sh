#!/usr/bin/env bash
# Render a Coercia (or vanilla) entity via the FBSR Nix flake — a
# headless preview of the engine render, no playtest needed. Iteration
# loop is ~30 seconds once the Maven cache is warm.
#
#   ./scripts/render-entity.sh                     # default entity below
#   ./scripts/render-entity.sh deep-core-miner     # any entity in our profile
#
# CAVEAT — FBSR does NOT honor `apply_recipe_tint`. It reads sprites raw
# without consulting recipe_not_set_tint / apply_recipe_tint, so the
# render is faithful for sprites referenced directly by `filename`
# (animation layers, the `crane` field) but UNDER-tints layers that rely
# on the engine's recipe-tint multiplication. If you've changed a
# recipe-tint field, FBSR won't show it — fall back to a playtest.
#
# Override the flake URL via FBSR_FLAKE env var if you've forked it.

set -euo pipefail

cd "$(dirname "$0")/.."
REPO_ROOT=$(pwd)
# No Coercia entities exist yet — default to a vanilla one so the script
# works on the empty skeleton. Change this to a Coercia entity once one
# exists (e.g. deep-core-miner, induction-boiler).
ENTITY="${1:-assembling-machine-2}"
FBSR_FLAKE="${FBSR_FLAKE:-github:Skeen/Factorio-FBSR-nix}"
DATA="${FBSR_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/fbsr-coercia}"
PROFILE="coercia"

# FBSR's profile-test-entity render uses AWT, which throws
# java.awt.HeadlessException on a headless box. The JVM honours
# JAVA_TOOL_OPTIONS automatically, so force headless mode.
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-Djava.awt.headless=true"

if [ ! -d "$REPO_ROOT/factorio" ]; then
  echo "Factorio install not found at $REPO_ROOT/factorio." >&2
  exit 1
fi

mkdir -p "$DATA/profiles/$PROFILE" "$DATA/build/$PROFILE/mods" \
         "$DATA/profiles/vanilla" "$DATA/build/vanilla/mods"

# Point FBSR at our Factorio install. `cfg-factorio` writes config.json.
cd "$DATA"
echo "==> Configuring Factorio install" >&2
echo "exit" | nix run --extra-experimental-features 'nix-command flakes' "$FBSR_FLAKE" >/dev/null 2>&1 || true  # bootstrap config.json
nix-shell -p jq --run "jq \
  --arg install '$REPO_ROOT/factorio' \
  --arg executable 'bin/x64/factorio' \
  '.factorio.install = \$install | .factorio.executable = \$executable' \
  '$DATA/config.json' > '$DATA/config.json.new' && mv '$DATA/config.json.new' '$DATA/config.json'"

# ── Vanilla base profile ────────────────────────────────────────────
# FBSR composes modded assets ON TOP of a built `vanilla` profile, so we
# scaffold it here: builtins only, hand-written manifest with zips:{} to
# bypass the portal-dependent build-manifest.
cat > "$DATA/profiles/vanilla/profile.json" <<'JSON'
{
  "enabled": true,
  "mods": ["base", "space-age", "quality", "elevated-rails"],
  "mod-overrides": {},
  "entity-overrides": {},
  "tile-overrides": {}
}
JSON
mkdir -p "$DATA/build/vanilla/mods"
cat > "$DATA/build/vanilla/mods/mod-list.json" <<'JSON'
{"mods":[
{"name":"base","enabled":true},
{"name":"elevated-rails","enabled":true},
{"name":"quality","enabled":true},
{"name":"space-age","enabled":true}
]}
JSON
cat > "$DATA/build/vanilla/manifest.json" <<'JSON'
{
  "mods": [
    {"name": "base", "title": "Base", "builtin": true},
    {"name": "quality", "title": "Quality", "builtin": true},
    {"name": "elevated-rails", "title": "Elevated Rails", "builtin": true},
    {"name": "space-age", "title": "Space Age", "builtin": true}
  ],
  "zips": {}
}
JSON

# ── Coercia profile ─────────────────────────────────────────────────
# entity-overrides pins the mod association for entities FBSR can't
# resolve on its own. FBSR infers an entity's owning mod from a mod-owned
# graphics filename it references; entities that are pure deep-copies of a
# vanilla prototype still point all their graphics at __base__/
# __space-age__, so FBSR finds no coercia file and logs "Entity X has no
# mods associated with it in a non-vanilla profile!" which ABORTS the
# whole profile build. Every deep-copy-based Coercia building will
# therefore need an entry here, e.g.:
#   "deep-core-miner": {"mods": ["coercia"]}   (deep-copy of a vanilla model)
# Empty for now (no Coercia entities yet).
cat > "$DATA/profiles/$PROFILE/profile.json" <<JSON
{
  "enabled": true,
  "mods": [
    "base", "space-age", "quality", "elevated-rails",
    "coercia"
  ],
  "mod-overrides": {},
  "entity-overrides": {},
  "tile-overrides": {}
}
JSON

# Symlink mods so FBSR's --mod-directory picks them up.
cd "$DATA/build/$PROFILE/mods"
ln -sfn "$REPO_ROOT/mods/coercia" coercia_0.1.0

cat > mod-list.json <<'JSON'
{"mods":[
{"name":"base","enabled":true},
{"name":"elevated-rails","enabled":true},
{"name":"quality","enabled":true},
{"name":"space-age","enabled":true},
{"name":"coercia","enabled":true}
]}
JSON

# Hand-written manifest bypasses FBSR's portal-dependent build-manifest.
# `zips: {}` makes hasDownloaded() pass on symlinks.
cat > "$DATA/build/$PROFILE/manifest.json" <<'JSON'
{
  "mods": [
    {"name": "base", "title": "Base", "builtin": true},
    {"name": "quality", "title": "Quality", "builtin": true},
    {"name": "elevated-rails", "title": "Elevated Rails", "builtin": true},
    {"name": "space-age", "title": "Space Age", "builtin": true},
    {"name": "coercia", "title": "Coercia", "version": "0.1.0", "category": "content", "tags": [], "downloads": 0, "owner": "you", "updated": "2026-01-01"}
  ],
  "zips": {}
}
JSON

# Build + render. FBSR's CLI is a stdin REPL (one command per line) —
# the `--` argv form is rejected. Build the vanilla base profile first
# (FBSR composes modded assets on top of it), then coercia, then render.
cd "$DATA"
echo "==> Building vanilla base + coercia, rendering $ENTITY" >&2
printf 'build-dump vanilla\nbuild-assets vanilla\nbuild-dump coercia\nbuild-assets coercia -force\nprofile-test-entity coercia %s\nexit\n' "$ENTITY" \
  | nix run --extra-experimental-features 'nix-command flakes' "$FBSR_FLAKE"

# NOTE: FBSR renders + saves the PNG, then tries to auto-open it in a
# desktop viewer, which throws java.awt.HeadlessException on a headless
# box and prints a scary "Failed to render test image" + stack trace.
# That is BENIGN — the render already succeeded and the PNG is written.
# The PNG-exists check below is the real success signal.
OUT="$DATA/build/$PROFILE/tests/$PROFILE-$ENTITY.png"
if [ -f "$OUT" ]; then
  echo "Render at: $OUT"
  echo "(ignore any 'Failed to render test image' / HeadlessException above — that's FBSR's harmless auto-open-in-viewer step; the PNG is valid.)"
else
  echo "Render failed: PNG not produced at $OUT" >&2
  exit 1
fi
