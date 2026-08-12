#!/usr/bin/env bash
# Guard (ci-eao): no factorio-test integration suite may exist that NO runner
# ever executes.
#
# The default `cindra-test` runner (scripts/cindra-test.sh) only points
# `--mod-path` at mods/cindra, so a standalone sibling mod that boots its own
# factorio-test suite in control.lua runs in ZERO pipelines -- its it()s rot
# silently and give false confidence. That is exactly how the flare-poc /
# mass-driver / freeze-radius-poc spikes ended up with ~48 never-run tests
# (ci-eao).
#
# This test enumerates every mod that ships a tests/ directory and asserts each
# one is in RUNNER_COVERED below -- the set of mods a runner actually executes.
# A new mod with a tests/ dir FAILS this guard until it is either:
#   * wired into a runner AND added to RUNNER_COVERED (with its runner named), or
#   * removed (spike concluded / behavior folded into mods/cindra).
#
# Deliberately narrow: it only tracks integration suites (mods/*/tests/). Pure
# unit tests (mods/*/unit-tests/) are already all run by `npm run test:unit`,
# which globs every such dir, so they cannot be orphaned.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO"

fail() { echo "FAIL: $*" >&2; exit 1; }

# Mods whose tests/ suite a runner actually executes.
#   cindra      -> `cindra-test` (scripts/cindra-test.sh: --mod-path mods/cindra), the default
#                  integration suite; also `npm run test:integration`.
#   env-scanner -> documented per-MR run: factorio-test --mod-path mods/env-scanner
#                  (cindra-test does not sweep it; env-scanner MRs run it directly).
RUNNER_COVERED=" cindra env-scanner "

# Echo one "mod (dir)" line per mod under $base/mods/*/tests whose suite holds
# .lua files but is NOT listed in the $covered set (space-padded, e.g. " a b ").
#
# Portable glob only: the flake dev-shell bash (nix bash 5.3+) does NOT ship
# `compgen` (ci-0zqn), so the previous `compgen -G ... || continue` errored
# (exit 127) under `set -e` for EVERY dir and skipped them all -- the guard then
# passed unconditionally regardless of orphans. A plain glob + existence probe
# needs no `compgen`.
find_orphans() {
  local base=$1 covered=$2
  local tests_dir mod
  local lua_files
  for tests_dir in "$base"/mods/*/tests; do
    [ -d "$tests_dir" ] || continue
    # With nullglob off (bash default) an empty match leaves the literal
    # pattern as element 0, which -e rejects -- so a tests/ dir holding no
    # .lua files is correctly treated as "not a suite" and skipped.
    lua_files=("$tests_dir"/*.lua)
    [ -e "${lua_files[0]:-}" ] || continue
    mod=$(basename "$(dirname "$tests_dir")")
    case "$covered" in
      *" $mod "*) : ;;                              # covered
      *) printf '%s (%s)\n' "$mod" "$tests_dir" ;;  # nobody runs it
    esac
  done
}

# Self-test (ci-0zqn): prove the detection loop actually flags an orphan on a
# throwaway fixture tree. This fails loudly if find_orphans ever goes vacuous
# again (e.g. a builtin it leans on vanishes from the runtime bash) instead of
# silently passing and giving false assurance.
selftest_detection() {
  local tmp out
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/mods/covered-fixture/tests" \
           "$tmp/mods/orphan-fixture/tests" \
           "$tmp/mods/empty-fixture/tests"
  : > "$tmp/mods/covered-fixture/tests/spec.lua"
  : > "$tmp/mods/orphan-fixture/tests/spec.lua"
  # empty-fixture/tests deliberately has NO .lua file.

  out=$(find_orphans "$tmp" " covered-fixture ")
  case "$out" in
    *orphan-fixture*) : ;;
    *) fail "self-test: orphan suite not detected -- detection loop is vacuous" ;;
  esac
  case "$out" in
    *covered-fixture*) fail "self-test: covered mod wrongly flagged as orphan" ;;
  esac
  case "$out" in
    *empty-fixture*) fail "self-test: empty tests/ dir wrongly flagged as suite" ;;
  esac
}

selftest_detection

mapfile -t orphans < <(find_orphans "$REPO" "$RUNNER_COVERED")

if [ "${#orphans[@]}" -ne 0 ]; then
  printf 'orphaned integration suite (no runner executes it):\n' >&2
  printf '  - %s\n' "${orphans[@]}" >&2
  fail "wire each into a runner (+ add to RUNNER_COVERED) or remove it"
fi

echo "ok - every mods/*/tests/ integration suite is executed by a runner"
