#!/usr/bin/env bash
# The in-engine integration-suite entrypoint: seed the data dir and run
# factorio-test against a REAL Factorio binary.
#
# `cindra-test` in the flake dev shell is a thin wrapper that exports
# FACTORIO_TEST_MOD (the flake-built factorio-test mod) and exec's this script,
# so the runner logic lives in the repo where it can be read, diffed and TESTED
# (tests/factorio-resolve.test.sh) instead of inside a nix string.
#
# USAGE (ci-fqep):
#
#   cindra-test [EXTRA-MOD ...] [-- CLI-ARG ...]
#
# Bare words before `--` are EXTRA MODS to enable alongside the DLC set
# (`cindra-test cindra-start cindra-dev-default`). Everything after `--` goes to
# the CLI verbatim -- flags and/or Lua filter patterns
# (`cindra-test any-planet-start cindra-start -- "cindra APS start chain"`).
# An option-looking arg before `--` is REFUSED rather than reinterpreted: it
# used to terminate the variadic `--mods` list, which silently demoted the mod
# names that followed into FILTER patterns, so the run quietly dropped a mod and
# still looked like the run that had it (observed: 525 tests -> 501, with APS
# never enabled).
#
# A run that executes ZERO tests is a FAILURE here, whatever the CLI says: a
# filter that stops matching (a renamed describe block) otherwise reports
# "525 skipped, 0 passed" and exits 0, i.e. a gate that passed without running.
# Same principle as the ci-j340 missing-engine gate below.
#
# CINDRA_ORIENTATION=horizontal runs the whole thing against the E-W ribbon
# instead of the default N-S one (ci-vjc). The orientation is a STARTUP setting
# baked into the tile/resource noise expressions at the DATA stage, so it can
# only be proven end-to-end by a SECOND engine run configured horizontal -- see
# mods/cindra-dev-horizontal and `npm run test:integration:horizontal`.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"

# ARGUMENT GRAMMAR (ci-fqep). Two channels, no overlap: extra MODS before `--`,
# raw CLI args after it. Anything ambiguous is a hard usage error -- never a
# silent reinterpretation, because both of the old reinterpretations (mod name
# read as a filter, filter read as a mod name) produce a run that still exits 0
# and still prints a summary that looks like the run you asked for.
extra_mods=()
cli_extra_args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --)
      shift
      cli_extra_args=("$@")
      break
      ;;
    -*)
      echo "error: '$1' is a factorio-test CLI option, but it appears before the mod names." >&2
      echo "It would terminate the '--mods' list and silently demote the mods to test filters." >&2
      echo "Put CLI options after a '--' separator: cindra-test [MOD ...] -- $*" >&2
      exit 2
      ;;
    *)
      # Mod names only. A filter pattern (spaces, Lua magic chars) landing here
      # would be handed to the CLI as a mod to install, so refuse it and say
      # where it belongs.
      case "$1" in
        *[!A-Za-z0-9_.=-]* | "")
          echo "error: '$1' is not a mod name, and args before '--' are mod names." >&2
          echo "Test filters and CLI options go after a '--' separator:" >&2
          echo "  cindra-test [MOD ...] -- \"$1\"" >&2
          exit 2
          ;;
      esac
      extra_mods+=("$1")
      shift
      ;;
  esac
done

ft_mod="${FACTORIO_TEST_MOD:-}"
if [ -z "$ft_mod" ] || [ ! -f "$ft_mod/info.json" ]; then
  echo "error: FACTORIO_TEST_MOD does not point at a built factorio-test mod." >&2
  echo "Run the suite from the flake dev shell: 'nix develop' then 'cindra-test'." >&2
  exit 1
fi

# HARD GATE (ci-j340): resolve the engine BEFORE touching anything else, and let
# a failure be exactly that -- a non-zero exit with a loud message. A missing
# binary must never degrade into a soft "in-engine step skipped", because then
# every bead whose acceptance is "verified in-engine" is unenforceable: the run
# looks like it happened and nothing ran.
factorio_path="$("$repo/scripts/resolve-factorio.sh" "$repo")" || exit 1

data_dir="${FACTORIO_TEST_DATA_DIR:-$repo/factorio-test-data-dir}"
version="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$ft_mod/info.json" | head -1)"

mkdir -p "$data_dir/mods"
# CANONICAL settings: drop any persisted mod-settings.dat so every run
# regenerates it from the CURRENT settings.lua defaults. Factorio only
# reads a startup setting's default_value when the name is ABSENT from
# mod-settings.dat; once the file exists it keeps the stored value and
# IGNORES a changed default. A data dir reused across runs (locally, or
# on the refinery's persistent workspace) therefore pins STALE zone
# widths, so a geometry change (e.g. ci-qqt's thin 128-tile ribbon) reads
# green on a fresh checkout but red on a reused one -- the exact false-
# green/stale-red split that rejected the first ci-qqt attempt. Deleting
# it makes every run deterministic against the code's own defaults (the
# tests already assume vanilla-default settings). Custom local tuning is
# transient test state, not source, so nothing durable is lost.
rm -f "$data_dir/mods/mod-settings.dat"
ln -sfn "$ft_mod" "$data_dir/mods/factorio-test_$version"
# env-scanner is a required (~) dependency of cindra: cindra will not
# load without it, and its scanner must exist for the suite to assert
# on. It is a sibling local mod (not on the portal), so seed it into
# the data dir like factorio-test; cindra's ~ dep then auto-enables it.
ln -sfn "$repo/mods/env-scanner" "$data_dir/mods/env-scanner"

# ORIENTATION (ci-vjc). The ribbon's orientation is a startup setting, so one
# engine run = one orientation: nothing at runtime can rotate a world whose tile
# and resource noise expressions were already built vertical. The horizontal
# (E-W) ribbon is therefore proven by re-running the suite with the dev mod that
# flips the setting's DEFAULT (mods/cindra-dev-horizontal); the mod-settings.dat
# deletion above is what makes a changed default take effect.
#
# The seed is added ONLY for a horizontal run and REMOVED otherwise: the data
# dir is reused between runs, and Factorio enables a mod it finds there but does
# not know about, so a leftover symlink would silently rotate the NEXT default
# run's world.
orientation_mods=()
case "${CINDRA_ORIENTATION:-vertical}" in
  horizontal)
    ln -sfn "$repo/mods/cindra-dev-horizontal" "$data_dir/mods/cindra-dev-horizontal"
    orientation_mods=(cindra-dev-horizontal)
    ;;
  vertical)
    rm -f "$data_dir/mods/cindra-dev-horizontal"
    ;;
  *)
    echo "error: CINDRA_ORIENTATION must be 'vertical' or 'horizontal', got '$CINDRA_ORIENTATION'." >&2
    exit 1
    ;;
esac

cli="$repo/node_modules/.bin/factorio-test"
if [ ! -x "$cli" ]; then
  echo "error: factorio-test-cli not installed; run 'npm install' first (see SETUP.md)." >&2
  exit 1
fi

# ARGV ORDER (ci-fqep). The variadic `--mods` list comes FIRST and is closed by
# the next option, so it can never swallow a trailing filter pattern; the last
# thing before the user's args is a single-value option (`--mod-path`), so a
# bare word from `--` onwards reaches the CLI as the positional filter it is and
# a flag reaches it as a flag. The old order (`--mods ... "$@"`) made both of
# those depend on what the user happened to type first.
cli_argv=(run
  --mods space-age quality elevated-rails recycler
    ${orientation_mods[@]+"${orientation_mods[@]}"}
    ${extra_mods[@]+"${extra_mods[@]}"}
  --factorio-path "$factorio_path"
  --data-directory "$data_dir"
  --mod-path "$repo/mods/cindra"
  ${cli_extra_args[@]+"${cli_extra_args[@]}"})

# ZERO-TEST GATE (ci-fqep). Tee stdout so the summary line can be read back
# after the run streams normally. stderr is left alone.
run_log="$(mktemp "${TMPDIR:-/tmp}/cindra-test-summary.XXXXXX")"
trap 'rm -f "$run_log"' EXIT

set +e
"$cli" "${cli_argv[@]}" | tee "$run_log"
status=${PIPESTATUS[0]}
set -e

[ "$status" -eq 0 ] || exit "$status"

# `Tests: 3 failed, 12 skipped, 510 passed (525 total)`, colours stripped.
esc=$(printf '\033')
summary="$(sed "s/${esc}\[[0-9;]*[a-zA-Z]//g" "$run_log" | grep -E '^Tests: ' | tail -1 || true)"

if [ -z "$summary" ]; then
  echo "error: the CLI exited 0 but printed no test summary, so nothing proves the suite ran." >&2
  echo "Treat this as a FAILED run, not a passing one." >&2
  exit 1
fi

passed=0
if [[ $summary =~ ([0-9]+)\ passed ]]; then
  passed=${BASH_REMATCH[1]}
fi

if [ "$passed" -eq 0 ]; then
  echo "error: the run executed ZERO tests ($summary)." >&2
  echo "A filter that matches nothing skips every test and the CLI still exits 0," >&2
  echo "which reads as a passing gate that never ran. Failing instead." >&2
  exit 1
fi
