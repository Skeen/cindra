#!/usr/bin/env bash
# Guard (ci-vjc): the HORIZONTAL-orientation in-engine run stays wired up.
#
# The ribbon's orientation is a STARTUP setting baked into the tile probability
# expressions and the resource band masks at the DATA stage, so one Factorio run
# generates exactly one orientation. Proving the E-W ribbon end-to-end therefore
# takes a SECOND run configured horizontal -- and a second run is exactly the kind
# of thing that quietly stops happening: drop one npm script and
# mods/cindra/tests/test_worldgen_horizontal.lua never executes again, while the
# default suite stays green and nobody notices (the ci-eao orphan-suite failure
# mode, in a shape tests/no-orphan-suites.test.sh cannot see -- the file lives in
# a mod that IS covered by a runner).
#
# So this asserts the observable behaviour of the runner and its wiring:
#   1. CINDRA_ORIENTATION=horizontal seeds the orientation dev mod and ENABLES it;
#   2. the default run does NOT -- and actively REMOVES a stale seed, because the
#      data dir is reused and Factorio enables a mod it finds there, which would
#      silently rotate the next default run's world;
#   3. a bogus value is a loud failure, never a silent fallback to vertical;
#   4. an npm script runs the horizontal suite, and `npm test` includes it;
#   5. the suite file is registered by control.lua (so it can actually load).
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# A hermetic stand-in for a checkout: the real scripts/mods, a stub engine and a
# stub factorio-test CLI that just dumps the args it was handed. No game boots.
# ---------------------------------------------------------------------------
WS="$TMP/ws"
mkdir -p "$WS/factorio-patched/bin/x64" "$WS/repo/node_modules/.bin" "$TMP/ftmod"
cat > "$WS/factorio-patched/bin/x64/factorio" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$WS/factorio-patched/bin/x64/factorio"
ln -sfn "$REPO/scripts" "$WS/repo/scripts"
ln -sfn "$REPO/mods" "$WS/repo/mods"
printf '{ "name": "factorio-test", "version": "3.1.1" }\n' > "$TMP/ftmod/info.json"
# The summary line is not decoration: the runner FAILS a run that executed no
# tests (ci-fqep), so a stub that prints nothing would look like a dead run.
cat > "$WS/repo/node_modules/.bin/factorio-test" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$TMP/cli-args.txt"
echo 'Tests: 525 passed (525 total)'
exit 0
EOF
chmod +x "$WS/repo/node_modules/.bin/factorio-test"

DD="$TMP/data-dir"
SEED="$DD/mods/cindra-dev-horizontal"

# run_runner [env=val ...] : invoke the integration entrypoint against the stubs.
run_runner() {
  : > "$TMP/cli-args.txt"
  (cd "$WS/repo" && env -u FACTORIO_PATH -u FACTORIO_DIR -u CINDRA_ORIENTATION \
      FACTORIO_TEST_MOD="$TMP/ftmod" FACTORIO_TEST_DATA_DIR="$DD" "$@" \
      ./scripts/cindra-test.sh) >/dev/null 2>"$TMP/err.txt"
}

# 1. HORIZONTAL: the dev mod is seeded into the data dir AND handed to the CLI.
run_runner CINDRA_ORIENTATION=horizontal \
  || { cat "$TMP/err.txt" >&2; fail "the horizontal run did not start"; }
[ -e "$SEED" ] || fail "the horizontal run did not seed mods/cindra-dev-horizontal into the data dir"
[ "$(readlink "$SEED")" = "$WS/repo/mods/cindra-dev-horizontal" ] \
  || fail "the seed points at '$(readlink "$SEED")', not the repo's orientation mod"
grep -qx 'cindra-dev-horizontal' "$TMP/cli-args.txt" \
  || fail "the horizontal run did not ENABLE cindra-dev-horizontal (a seeded-but-disabled mod changes nothing)"

# 2. DEFAULT: no orientation mod, and the stale seed from run 1 is cleaned up.
run_runner || { cat "$TMP/err.txt" >&2; fail "the default run did not start"; }
[ ! -e "$SEED" ] \
  || fail "the default run left cindra-dev-horizontal in the reused data dir -- it would rotate this world"
grep -qx 'cindra-dev-horizontal' "$TMP/cli-args.txt" \
  && fail "the default run enabled the orientation override" || true

# 3. A typo must be fatal, not a silent vertical run wearing a horizontal label.
if run_runner CINDRA_ORIENTATION=sideways; then
  fail "CINDRA_ORIENTATION=sideways ran anyway -- a bogus orientation must fail loudly"
fi
grep -qi "CINDRA_ORIENTATION" "$TMP/err.txt" \
  || { cat "$TMP/err.txt" >&2; fail "the bogus-orientation failure does not name the variable"; }

# ---------------------------------------------------------------------------
# 4./5. The wiring that makes the run actually happen, and the suite loadable.
# ---------------------------------------------------------------------------
grep -q '"test:integration:horizontal": *"CINDRA_ORIENTATION=horizontal cindra-test' "$REPO/package.json" \
  || fail "package.json has no test:integration:horizontal script running cindra-test horizontally"
grep -q '"test": *".*npm run test:integration:horizontal' "$REPO/package.json" \
  || fail "'npm test' does not run the horizontal suite -- it would rot unnoticed"

grep -q 'tests/test_worldgen_horizontal' "$REPO/mods/cindra/control.lua" \
  || fail "control.lua never registers tests/test_worldgen_horizontal -- the suite would never load"
[ -f "$REPO/mods/cindra/tests/test_worldgen_horizontal.lua" ] \
  || fail "the horizontal worldgen suite is missing"
grep -q 'default_value *= *"horizontal"' "$REPO/mods/cindra-dev-horizontal/settings-updates.lua" \
  || fail "mods/cindra-dev-horizontal does not flip the orientation default to horizontal"

echo "PASS: the horizontal-orientation run is wired end to end (seeded, enabled, cleaned up, and in 'npm test')"
