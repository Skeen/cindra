#!/usr/bin/env bash
# Resolve the local Factorio binary, print its path, or FAIL LOUDLY (ci-j340).
#
# ONE source of truth for install discovery, shared by every entrypoint that
# needs the engine: play.sh, the integration runner (scripts/cindra-test.sh,
# which the flake's `cindra-test` wraps) and the in-engine render harnesses.
# Divergent copies of this logic are how the problem stayed invisible: the old
# chain ended at the in-repo ./factorio symlink, NOTHING in this repo ever
# creates that symlink, and a fresh worktree therefore came up with no reachable
# engine at all -- while a perfectly good shared install sat a few directories
# up. Agents then landed "could not verify in-engine" work with the engine
# available the whole time.
#
# Usage: scripts/resolve-factorio.sh [search-root]
#   search-root defaults to the repo root (this script's parent directory).
#
# Prints the binary path on stdout. On failure prints a diagnostic on stderr and
# exits 1 -- callers MUST propagate that failure. A missing engine is never a
# soft "skipped/unverified": that turns "verified in-engine" into a claim nobody
# checks, the same way an implementation-restating test turns green into a claim
# nobody checks.
#
# Order, first hit wins:
#   1. $FACTORIO_PATH                       explicit binary
#   2. $FACTORIO_DIR/bin/x64/factorio       explicit install root
#   3. <search-root>/factorio/bin/x64/...   in-repo install or symlink
#   4. factorio-patched/ then factorio/ in <search-root> and EVERY parent
#      directory, up to /
#
# 1 and 2 are deliberate overrides, so a set-but-broken one is an error rather
# than a silent fall-through to something else. 4 is what makes a bare worktree
# work: worktrees live at <workspace>/hq/<rig>/polecats/<name>/<repo> and the
# shared install sits at <workspace>/factorio-patched, so walking up finds it
# from any depth. The install is a manual, gitignored, host-specific ~250MB
# tree, so its path must NOT be hardcoded anywhere -- relative discovery is the
# whole point.
set -euo pipefail

BIN_SUBPATH=bin/x64/factorio
# Install-root names tried at each level, in preference order. factorio-patched
# first: where both exist, the patched one is the one that actually launches on
# NixOS (see scripts/patchelf-factorio.sh).
INSTALL_NAMES="factorio-patched factorio"

root=${1:-$(cd "$(dirname "$0")/.." && pwd)}

usable() { [ -f "$1" ] && [ -x "$1" ]; }

if [ -n "${FACTORIO_PATH:-}" ]; then
  if usable "$FACTORIO_PATH"; then
    printf '%s\n' "$FACTORIO_PATH"
    exit 0
  fi
  echo "error: FACTORIO_PATH is set to '$FACTORIO_PATH', which is not an executable file." >&2
  echo "Fix or unset it (unset falls back to install discovery); see SETUP.md." >&2
  exit 1
fi

if [ -n "${FACTORIO_DIR:-}" ]; then
  bin="$FACTORIO_DIR/$BIN_SUBPATH"
  if usable "$bin"; then
    printf '%s\n' "$bin"
    exit 0
  fi
  echo "error: FACTORIO_DIR is set to '$FACTORIO_DIR', but '$bin' is not an executable file." >&2
  echo "Fix or unset it (unset falls back to install discovery); see SETUP.md." >&2
  exit 1
fi

searched=()

# 3. The in-repo install / symlink keeps its historical priority, so an
#    intentional per-clone override still beats anything found further up.
in_repo="$root/factorio/$BIN_SUBPATH"
searched+=("$in_repo")
if usable "$in_repo"; then
  printf '%s\n' "$in_repo"
  exit 0
fi

# 4. Upward search. Starts AT the search root (so an in-repo factorio-patched/ is
#    found too) and stops after /.
dir=$root
while :; do
  prefix=${dir%/}   # "/" -> "" so we build /factorio, not //factorio
  for name in $INSTALL_NAMES; do
    candidate="$prefix/$name/$BIN_SUBPATH"
    [ "$candidate" = "$in_repo" ] || searched+=("$candidate")   # already reported above
    if usable "$candidate"; then
      printf '%s\n' "$candidate"
      exit 0
    fi
  done
  [ "$dir" = "/" ] && break
  dir=$(dirname "$dir")
done

{
  echo "error: NO FACTORIO ENGINE FOUND -- nothing can be verified in-engine."
  echo
  echo "Searched, in order:"
  echo "  \$FACTORIO_PATH                   (unset)"
  echo "  \$FACTORIO_DIR/$BIN_SUBPATH   (unset)"
  printf '  %s\n' "${searched[@]}"
  echo
  echo "The game is a manual, gitignored, host-specific install (see SETUP.md)."
  echo "Provide one by either:"
  echo "  * symlinking a shared install into this repo:  ln -sfn /path/to/install $root/factorio"
  echo "  * putting/naming a shared install as 'factorio-patched' in a parent directory"
  echo "  * setting FACTORIO_PATH (binary) or FACTORIO_DIR (install root)"
  echo
  echo "Until then: do NOT report an in-engine result, and do NOT close a bead"
  echo "whose acceptance requires one. Escalate or leave the work open."
} >&2
exit 1
