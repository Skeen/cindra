#!/usr/bin/env bash
# The in-engine integration-suite entrypoint: seed the data dir and run
# factorio-test against a REAL Factorio binary.
#
# `cindra-test` in the flake dev shell is a thin wrapper that exports
# FACTORIO_TEST_MOD (the flake-built factorio-test mod) and exec's this script,
# so the runner logic lives in the repo where it can be read, diffed and TESTED
# (tests/factorio-resolve.test.sh) instead of inside a nix string.
#
# Extra args are forwarded to the CLI (e.g. a suite filter, or the companion
# mods: `cindra-test cindra-start cindra-dev-default`).
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"

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

cli="$repo/node_modules/.bin/factorio-test"
if [ ! -x "$cli" ]; then
  echo "error: factorio-test-cli not installed; run 'npm install' first (see SETUP.md)." >&2
  exit 1
fi

exec "$cli" run \
  --factorio-path "$factorio_path" \
  --data-directory "$data_dir" \
  --mod-path "$repo/mods/cindra" \
  --mods space-age quality elevated-rails recycler "$@"
