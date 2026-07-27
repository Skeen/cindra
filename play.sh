#!/usr/bin/env bash
# Launch Factorio with the cindra mod + the full Cindra playtest mod set:
# the Any-Planet-Start start chain (any-planet-start + cindra-start +
# cindra-dev-default) so `New Game` lands you on Cindra, plus Helmod for
# recipe/ratio math. APS and Helmod are NOT vendored in this repo (APS is a
# deliberately optional external dependency; Helmod is a big third-party mod);
# play.sh finds a local copy or fetches one into a gitignored cache. The binary
# at factorio/bin/x64/factorio is patchelf'd for NixOS (interpreter + RUNPATH
# point at nix-store paths), so it runs without steam-run.
set -eu
cd "$(dirname "$0")"

# Resolve the Factorio binary. The ~4GB install is gitignored, so a fresh clone
# has none; point one of these at a SHARED install to avoid a copy per clone:
#   FACTORIO_PATH  full path to the binary        (highest priority)
#   FACTORIO_DIR   install root (binary at $FACTORIO_DIR/bin/x64/factorio)
# Default is the in-repo ./factorio (real dir or symlink to a shared install).
if [ -n "${FACTORIO_PATH:-}" ]; then
  FACTORIO_BIN="$FACTORIO_PATH"
elif [ -n "${FACTORIO_DIR:-}" ]; then
  FACTORIO_BIN="$FACTORIO_DIR/bin/x64/factorio"
else
  FACTORIO_BIN="./factorio/bin/x64/factorio"
fi

if [ ! -x "$FACTORIO_BIN" ]; then
  echo "Factorio binary not found at: $FACTORIO_BIN" >&2
  echo "The game is a manual, local install (gitignored, see SETUP.md)." >&2
  echo "Set FACTORIO_PATH (binary) or FACTORIO_DIR (install root) to a shared install," >&2
  echo "or extract one to ./factorio." >&2
  exit 1
fi

# The install root holds mods/ and player-data.json (bin/x64/factorio -> root).
FACTORIO_ROOT=$(cd "$(dirname "$FACTORIO_BIN")/../.." && pwd)

# Guard: if the binary lost its RUNPATH (steam update, fresh extraction, etc.)
# SDL will crash deep in SDLWindow.cpp with the misleading "No available video
# device". Catch it here with a clear pointer to the fix. Only enforced for a
# real dynamic ELF, so a test stub (plain script) sails through.
if command -v readelf >/dev/null 2>&1 \
   && readelf -d "$FACTORIO_BIN" 2>/dev/null | grep -q 'Dynamic section' \
   && ! readelf -d "$FACTORIO_BIN" 2>/dev/null | grep -q 'R\(UN\)\?PATH'; then
  echo "Factorio binary has no RUNPATH; SDL will fail to find libX11/libXss/libGL." >&2
  echo "Re-patchelf it with: ./scripts/patchelf-factorio.sh" >&2
  exit 1
fi

# Cache for mods fetched from the portal (APS / Helmod). Gitignored; reused
# across launches so we download each mod at most once.
CACHE_DIR=.play-cache

MODS=mods-bundle
rm -rf "$MODS"   # wipe stale symlinks from earlier runs
mkdir -p "$MODS"

# link_mod <bundle-name> <target-path> : symlink a mod into the bundle so
# Factorio picks it up via --mod-directory. An unzipped mod goes in under its
# bare name (a dir); a zip MUST keep its `name_version.zip` filename or Factorio
# won't recognise it, so for zips we ignore <bundle-name> and reuse the basename.
link_mod() {
  local target; target=$(realpath "$2")
  local base=$1
  [ -d "$target" ] || base=$(basename "$target")
  ln -sfn "$target" "$MODS/$base"
}

link_mod cindra mods/cindra

# find_local_mod <mod-name> [extra-dir...] : echo the first local copy of a mod
# found as either an unzipped dir (<name>/) or a versioned zip (<name>_*.zip),
# searching the cache, the Factorio install's mods/, and any extra dirs. Empty
# output means "not found locally".
find_local_mod() {
  local name=$1; shift
  local dir
  for dir in "$CACHE_DIR" "$FACTORIO_ROOT/mods" "$@"; do
    [ -n "$dir" ] || continue
    if [ -d "$dir/$name" ]; then echo "$dir/$name"; return 0; fi
    local zip
    # shellcheck disable=SC2012  # mod filenames are controlled (name_version.zip)
    zip=$(ls "$dir/${name}"_*.zip 2>/dev/null | sort -V | tail -1 || true)
    if [ -n "$zip" ]; then echo "$zip"; return 0; fi
  done
  return 0
}

# --- Any-Planet-Start chain --------------------------------------------------
# APS lets cindra-start register Cindra as a startable planet and lets
# cindra-dev-default default the picker to Cindra (no clicks on New Game). We
# find APS via, in order: $APS_PATH (a dir or zip you point at), the local
# cache, the Factorio install's mods/, then fetch it from the portal. Only when
# APS is present do we wire the two Cindra companion mods (they harmlessly
# register nothing without it).
HAS_APS=0
APS_SRC=""
if [ -n "${APS_PATH:-}" ] && { [ -d "${APS_PATH:-}" ] || [ -f "${APS_PATH:-}" ]; }; then
  APS_SRC="$APS_PATH"
else
  APS_SRC=$(find_local_mod any-planet-start)
fi
if [ -z "$APS_SRC" ] && [ "${PLAY_NO_FETCH:-0}" != 1 ]; then
  APS_SRC=$(scripts/fetch-mod.sh any-planet-start "$FACTORIO_ROOT" "$CACHE_DIR" 2.1 || true)
fi
if [ -n "$APS_SRC" ]; then
  link_mod any-planet-start "$APS_SRC"
  link_mod cindra-start mods/cindra-start
  link_mod cindra-dev-default mods/cindra-dev-default
  HAS_APS=1
else
  echo "any-planet-start not found and not fetched; launching cindra without the APS start chain." >&2
fi

# --- Helmod (recipe/ratio calculator) ---------------------------------------
# Same discovery: $HELMOD_ZIP override, local cache, Factorio install's mods/
# (a shared install often already ships it), then fetch.
HAS_HELMOD=0
HELMOD_SRC=""
if [ -n "${HELMOD_ZIP:-}" ] && [ -f "${HELMOD_ZIP:-}" ]; then
  HELMOD_SRC="$HELMOD_ZIP"
else
  HELMOD_SRC=$(find_local_mod helmod)
fi
if [ -z "$HELMOD_SRC" ] && [ "${PLAY_NO_FETCH:-0}" != 1 ]; then
  HELMOD_SRC=$(scripts/fetch-mod.sh helmod "$FACTORIO_ROOT" "$CACHE_DIR" 2.1 || true)
fi
if [ -n "$HELMOD_SRC" ]; then
  link_mod helmod "$HELMOD_SRC"
  HAS_HELMOD=1
else
  echo "helmod not found and not fetched; launching without it." >&2
fi

# DLC mods (space-age, quality, elevated-rails) auto-load from factorio/data/ —
# don't symlink them here or you'll get "Duplicate mod" errors.

if [ "$HAS_APS" = 1 ]; then
  APS_LINES='    { "name": "any-planet-start", "enabled": true },
    { "name": "cindra-start", "enabled": true },
    { "name": "cindra-dev-default", "enabled": true },'
else
  APS_LINES=''
fi
if [ "$HAS_HELMOD" = 1 ]; then
  HELMOD_LINE='    { "name": "helmod", "enabled": true },'
else
  HELMOD_LINE=''
fi
# The optional APS / helmod blocks each end with a trailing comma, so cindra
# carries a comma and a DLC mod (space-age) is the guaranteed comma-free last
# entry. recycler is a required built-in DLC in 2.1 (quality / space-age depend
# on it).
cat > "$MODS/mod-list.json" <<JSON
{
  "mods": [
    { "name": "cindra", "enabled": true },
$APS_LINES
$HELMOD_LINE
    { "name": "base", "enabled": true },
    { "name": "elevated-rails", "enabled": true },
    { "name": "quality", "enabled": true },
    { "name": "recycler", "enabled": true },
    { "name": "space-age", "enabled": true }
  ]
}
JSON

exec "$FACTORIO_BIN" --mod-directory "$MODS" "$@"
