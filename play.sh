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

# Resolve the Factorio binary via the shared resolver (the one source of truth,
# also used by the integration runner and the render harnesses): FACTORIO_PATH,
# then FACTORIO_DIR, then the in-repo ./factorio, then factorio-patched/ or
# factorio/ in any parent directory. It prints the diagnostic and exits non-zero
# itself when there is no engine, so we just propagate that.
FACTORIO_BIN=$(scripts/resolve-factorio.sh "$PWD") || exit 1

# Resolve to an absolute, symlink-free path so the patchelf step below (and the
# FACTORIO_ROOT derivation) work regardless of how we were pointed at the binary
# (relative ./factorio, a symlink to a shared install, FACTORIO_DIR override).
FACTORIO_BIN=$(realpath "$FACTORIO_BIN")

# The install root holds mods/ and player-data.json (bin/x64/factorio -> root).
FACTORIO_ROOT=$(cd "$(dirname "$FACTORIO_BIN")/../.." && pwd)

# On NixOS a freshly extracted Factorio binary won't launch as-is: its ELF
# interpreter points at /lib64/ld-linux (absent on NixOS -> "cannot execute:
# required file not found"), and it carries no RUNPATH, so SDL later dies deep
# in SDLWindow.cpp with the misleading "No available video device".
# scripts/patchelf-factorio.sh bakes concrete nix-store paths in to fix both.
# Detect an unpatched binary and auto-run the patcher on it (set
# PLAY_NO_PATCHELF=1 to skip and just be told the command). Only a real dynamic
# ELF is inspected, so a plain-script test stub sails through. A missing
# interpreter is fatal on any distro, so that check is unconditional; the
# empty-RUNPATH check is gated on NixOS, since an FHS distro's Factorio has no
# RUNPATH yet finds its libs via the standard loader search.
PATCHELF_SCRIPT=${PLAY_PATCHELF_CMD:-scripts/patchelf-factorio.sh}
if command -v patchelf >/dev/null 2>&1; then
  interp=$(patchelf --print-interpreter "$FACTORIO_BIN" 2>/dev/null || true)
  if [ -n "$interp" ]; then   # empty => not an ELF (e.g. a test stub) => nothing to patch
    rpath=$(patchelf --print-rpath "$FACTORIO_BIN" 2>/dev/null || true)
    needs_patch=0
    [ -e "$interp" ] || needs_patch=1                          # loader missing -> can't exec anywhere
    [ -e /etc/NIXOS ] && [ -z "$rpath" ] && needs_patch=1      # no RUNPATH -> SDL fails on NixOS
    if [ "$needs_patch" = 1 ]; then
      if [ "${PLAY_NO_PATCHELF:-0}" = 1 ]; then
        echo "Factorio binary at $FACTORIO_BIN looks unpatched for NixOS (interpreter/RUNPATH)." >&2
        echo "Patch it with: ./scripts/patchelf-factorio.sh \"$FACTORIO_BIN\"" >&2
        exit 1
      fi
      echo "Factorio binary looks unpatched for NixOS; running patchelf-factorio.sh on it..." >&2
      "$PATCHELF_SCRIPT" "$FACTORIO_BIN" || {
        echo "patchelf-factorio.sh failed (see output above). Retry manually with:" >&2
        echo "  ./scripts/patchelf-factorio.sh \"$FACTORIO_BIN\"" >&2
        exit 1
      }
    fi
  fi
else
  echo "patchelf not on PATH; skipping the NixOS binary check." >&2
  echo "If the game won't launch, enter 'nix develop' and/or run ./scripts/patchelf-factorio.sh." >&2
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
# env-scanner is a required (~) dependency of cindra, so the two MUST load
# together or Factorio refuses the whole set. It is a sibling local mod, not on
# the portal, so wire it straight from mods/ like cindra itself.
link_mod env-scanner mods/env-scanner

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
    { "name": "env-scanner", "enabled": true },
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
