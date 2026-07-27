#!/usr/bin/env bash
# Test that play.sh wires the full Cindra playtest mod set into mods-bundle:
# cindra + the Any-Planet-Start start chain (any-planet-start + cindra-start +
# cindra-dev-default) + helmod, discovered automatically from a Factorio
# install's mods/ folder with NO APS_PATH and NO network.
#
# This fails on the old play.sh, which only wired APS when $APS_PATH was set and
# never included helmod. We stub the Factorio binary (records its args, exits 0)
# so nothing actually launches, and stub the mod files (their contents are never
# read here, only the symlink + mod-list wiring is).
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# --- Build a fake Factorio install --------------------------------------------
INSTALL="$TMP/factorio"
mkdir -p "$INSTALL/bin/x64" "$INSTALL/mods"

# Stub binary: append its args to a log, then exit 0. play.sh exec's this last,
# so a clean exit means the script ran to completion.
cat > "$INSTALL/bin/x64/factorio" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$TMP/launch-args.txt"
exit 0
EOF
chmod +x "$INSTALL/bin/x64/factorio"

# Local copies of the un-vendored mods, in the install's mods/ dir. APS ships as
# a versioned zip; helmod likewise. play.sh should discover both here without an
# APS_PATH override and without fetching.
: > "$INSTALL/mods/any-planet-start_1.2.2.zip"
: > "$INSTALL/mods/helmod_2.3.3.zip"

# --- Run play.sh --------------------------------------------------------------
# PLAY_NO_FETCH guards against any network attempt if discovery were to miss.
cd "$REPO"
env -u APS_PATH -u HELMOD_ZIP -u FACTORIO_DIR \
  FACTORIO_PATH="$INSTALL/bin/x64/factorio" \
  PLAY_NO_FETCH=1 \
  ./play.sh >/dev/null 2>"$TMP/play.err" \
  || { cat "$TMP/play.err" >&2; fail "play.sh exited non-zero"; }

BUNDLE="$REPO/mods-bundle"
LIST="$BUNDLE/mod-list.json"

# --- Assert the launch happened against the bundle ----------------------------
grep -qx -- '--mod-directory' "$TMP/launch-args.txt" \
  || fail "factorio not launched with --mod-directory"
grep -qx -- 'mods-bundle' "$TMP/launch-args.txt" \
  || fail "factorio not pointed at mods-bundle"

# --- Assert mod-list.json is valid and lists every required mod ---------------
[ -f "$LIST" ] || fail "no mod-list.json generated"
jq -e . "$LIST" >/dev/null || fail "mod-list.json is not valid JSON"

for mod in cindra cindra-start cindra-dev-default any-planet-start helmod \
           base elevated-rails quality recycler space-age; do
  jq -e --arg m "$mod" \
    'any(.mods[]; .name == $m and .enabled == true)' "$LIST" >/dev/null \
    || fail "mod-list.json missing enabled entry for '$mod'"
done

# --- Assert the symlinks resolve ----------------------------------------------
for name in cindra cindra-start cindra-dev-default; do
  [ -d "$BUNDLE/$name" ] || fail "bundle symlink '$name' does not resolve to a dir"
done
# Zipped mods keep their name_version.zip filename (Factorio requires it).
linked_zip() { ls "$BUNDLE/$1"_*.zip >/dev/null 2>&1; }
linked_zip any-planet-start || fail "any-planet-start zip not linked into bundle"
linked_zip helmod || fail "helmod zip not linked into bundle"

echo "PASS: play.sh wires cindra + APS chain + helmod into mods-bundle"
