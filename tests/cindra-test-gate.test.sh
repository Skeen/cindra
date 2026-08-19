#!/usr/bin/env bash
# Guard (ci-fqep): the integration runner must never report a run that did not
# happen, and must never quietly run a DIFFERENT run than the one asked for.
#
# Two silent-green mechanisms, both observed for real:
#
#   1. A filter that matches NOTHING exits 0 and prints
#      `Tests: 525 skipped, 0 passed (525 total)`. A CI step or agent whose
#      filter stops matching (a renamed describe block) reads that as PASS with
#      zero tests executed -- the ci-j340 missing-engine harm, from the other end.
#   2. `--mods space-age quality elevated-rails recycler "$@"` put the user's
#      args INSIDE a variadic option. An option-looking arg placed first closed
#      the list, so the mod names after it became positional FILTER patterns:
#      the run dropped any-planet-start entirely (total 525 -> 501) and still
#      looked exactly like the with-APS run it was supposed to be.
#
# What a user of this runner observes, and therefore what is asserted here:
#   A. zero executed tests => NON-ZERO exit, whatever the CLI's own exit code;
#   B. a real pass => zero exit, and genuine failures still surface as failures;
#   C. the DLC mods and any extra mods actually reach --mods, and a filter
#      NEVER does -- so a filtered APS run still has APS enabled;
#   D. an arg that could be read two ways is REFUSED, not reinterpreted, and
#      nothing is run.
#
# A stub CLI stands in for factorio-test: it records the argv it was handed and
# prints whatever summary line the case needs. No game boots.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# --- a hermetic checkout: real scripts/mods, stub engine, stub CLI -----------
WS="$TMP/ws"
mkdir -p "$WS/factorio-patched/bin/x64" "$WS/repo/node_modules/.bin" "$TMP/ftmod"
printf '#!/usr/bin/env bash\nexit 0\n' > "$WS/factorio-patched/bin/x64/factorio"
chmod +x "$WS/factorio-patched/bin/x64/factorio"
ln -sfn "$REPO/scripts" "$WS/repo/scripts"
ln -sfn "$REPO/mods" "$WS/repo/mods"
printf '{ "name": "factorio-test", "version": "3.1.1" }\n' > "$TMP/ftmod/info.json"

# The stub CLI echoes $STUB_SUMMARY (if any) and exits $STUB_EXIT, recording argv.
cat > "$WS/repo/node_modules/.bin/factorio-test" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$TMP/cli-args.txt"
[ -n "\${STUB_SUMMARY:-}" ] && printf '%s\n' "\$STUB_SUMMARY"
exit "\${STUB_EXIT:-0}"
EOF
chmod +x "$WS/repo/node_modules/.bin/factorio-test"

DD="$TMP/data-dir"

# run_runner [env=val ...] -- [runner args ...] : returns the runner's exit code.
run_runner() {
  local env_kv=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do env_kv+=("$1"); shift; done
  [ "${1:-}" = "--" ] && shift
  : > "$TMP/cli-args.txt"
  set +e
  (cd "$WS/repo" && env -u FACTORIO_PATH -u FACTORIO_DIR -u CINDRA_ORIENTATION \
      -u STUB_SUMMARY -u STUB_EXIT \
      FACTORIO_TEST_MOD="$TMP/ftmod" FACTORIO_TEST_DATA_DIR="$DD" \
      ${env_kv[@]+"${env_kv[@]}"} ./scripts/cindra-test.sh "$@") \
    >"$TMP/out.txt" 2>"$TMP/err.txt"
  local rc=$?
  set -e
  return "$rc"
}

# mods_arg_list : the words the CLI actually received as --mods values, i.e. up
# to the next option. This is what decides which mods get ENABLED.
mods_arg_list() {
  awk '/^--mods$/ {collect=1; next} collect && /^-/ {exit} collect {print}' "$TMP/cli-args.txt"
}
has_mod() { mods_arg_list | grep -qxF "$1"; }
# trailing_args : everything after the last option's value -- the CLI's
# positional filter patterns.
cli_has_positional() { grep -qxF "$1" "$TMP/cli-args.txt" && ! has_mod "$1"; }

PASS_LINE='Tests: 12 skipped, 501 passed (513 total)'
ZERO_LINE='Tests: 525 skipped, 0 passed (525 total)'

# ---------------------------------------------------------------------------
# A. A run that executed ZERO tests must FAIL, even though the CLI exited 0.
# ---------------------------------------------------------------------------
if run_runner STUB_SUMMARY="$ZERO_LINE" STUB_EXIT=0 --; then
  fail "a run reporting '$ZERO_LINE' exited ZERO -- a gate that ran nothing must never read as passed"
fi
grep -qi "zero tests" "$TMP/err.txt" \
  || { cat "$TMP/err.txt" >&2; fail "the zero-test failure does not say that nothing ran"; }
grep -qF "$ZERO_LINE" "$TMP/out.txt" \
  || fail "the runner swallowed the CLI's own output while capturing the summary"

# A CLI that exits 0 without ever printing a summary proves nothing either.
if run_runner STUB_EXIT=0 --; then
  fail "a run that printed NO summary exited ZERO -- nothing showed the suite ran"
fi

# ---------------------------------------------------------------------------
# B. A real run still passes, and a real failure still fails (the gate must not
#    invert or mask the CLI's own verdict).
# ---------------------------------------------------------------------------
run_runner STUB_SUMMARY="$PASS_LINE" STUB_EXIT=0 -- \
  || { cat "$TMP/err.txt" >&2; fail "a run with 501 passed did not exit zero"; }

if run_runner STUB_SUMMARY='Tests: 2 failed, 499 passed (501 total)' STUB_EXIT=1 --; then
  fail "a failing CLI run exited ZERO through the wrapper"
fi

# ---------------------------------------------------------------------------
# C. Extra mods are ENABLED, and a filter never eats them. This is the exact
#    APS shape whose total silently fell 525 -> 501.
# ---------------------------------------------------------------------------
run_runner STUB_SUMMARY="$PASS_LINE" -- any-planet-start cindra-start cindra-dev-default \
    -- "cindra APS start chain" \
  || { cat "$TMP/err.txt" >&2; fail "the filtered APS invocation did not run"; }
for m in space-age quality elevated-rails recycler any-planet-start cindra-start cindra-dev-default; do
  has_mod "$m" || fail "'$m' never reached --mods (mods enabled: $(mods_arg_list | tr '\n' ' '))"
done
cli_has_positional "cindra APS start chain" \
  || fail "the filter did not reach the CLI as a positional pattern"
has_mod "cindra APS start chain" \
  && fail "the filter pattern was handed over as a MOD NAME" || true

# ...and with no filter at all, the base DLC set is still exactly the base set.
run_runner STUB_SUMMARY="$PASS_LINE" -- \
  || { cat "$TMP/err.txt" >&2; fail "the plain invocation did not run"; }
for m in space-age quality elevated-rails recycler; do
  has_mod "$m" || fail "the plain run lost DLC mod '$m'"
done

# A trailing CLI FLAG stays a flag (npm run test:integration:graphics).
run_runner STUB_SUMMARY="$PASS_LINE" -- -- -g \
  || { cat "$TMP/err.txt" >&2; fail "'cindra-test -- -g' did not run"; }
grep -qx -- '-g' "$TMP/cli-args.txt" || fail "-g never reached the CLI"
for m in space-age quality elevated-rails recycler; do
  has_mod "$m" || fail "a trailing flag knocked DLC mod '$m' out of --mods"
done
grep -q '"test:integration:graphics": *"cindra-test -- -g"' "$REPO/package.json" \
  || fail "package.json's graphics script does not use the '--' separator the runner requires"

# ---------------------------------------------------------------------------
# D. Ambiguity is refused, loudly, and NOTHING is run.
# ---------------------------------------------------------------------------
if run_runner STUB_SUMMARY="$PASS_LINE" -- -g cindra-start; then
  fail "an option before the mod names was accepted -- it silently demotes those mods to filters"
fi
[ ! -s "$TMP/cli-args.txt" ] || fail "the CLI was invoked anyway with a rejected argument line"
grep -q -- "--" "$TMP/err.txt" \
  || { cat "$TMP/err.txt" >&2; fail "the rejection does not point at the '--' separator"; }

if run_runner STUB_SUMMARY="$PASS_LINE" -- "cindra APS start chain"; then
  fail "a filter pattern before '--' was accepted as a mod name"
fi
[ ! -s "$TMP/cli-args.txt" ] || fail "the CLI was invoked with a filter pattern as a mod"

echo "PASS: a zero-test run fails, extra mods really get enabled, and ambiguous args are refused"
