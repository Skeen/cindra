#!/usr/bin/env bash
# Guard (ci-eao): no factorio-test integration suite may exist that NO runner
# ever executes.
#
# The default `cindra-test` runner (flake.nix) only points `--mod-path` at
# mods/cindra, so a standalone sibling mod that boots its own factorio-test
# suite in control.lua runs in ZERO pipelines -- its it()s rot silently and give
# false confidence. That is exactly how the flare-poc / mass-driver /
# freeze-radius-poc spikes ended up with ~48 never-run tests (ci-eao).
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
#   cindra      -> `cindra-test` (flake.nix: --mod-path mods/cindra), the default
#                  integration suite; also `npm run test:integration`.
#   env-scanner -> documented per-MR run: factorio-test --mod-path mods/env-scanner
#                  (cindra-test does not sweep it; env-scanner MRs run it directly).
RUNNER_COVERED=" cindra env-scanner "

orphans=()
for tests_dir in mods/*/tests; do
  [ -d "$tests_dir" ] || continue
  # Skip a tests/ dir that holds no actual test files.
  compgen -G "$tests_dir/*.lua" > /dev/null || continue
  mod=$(basename "$(dirname "$tests_dir")")
  case "$RUNNER_COVERED" in
    *" $mod "*) : ;;                       # covered
    *) orphans+=("$mod ($tests_dir)") ;;   # nobody runs it
  esac
done

if [ "${#orphans[@]}" -ne 0 ]; then
  printf 'orphaned integration suite (no runner executes it):\n' >&2
  printf '  - %s\n' "${orphans[@]}" >&2
  fail "wire each into a runner (+ add to RUNNER_COVERED) or remove it"
fi

echo "ok - every mods/*/tests/ integration suite is executed by a runner"
