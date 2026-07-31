#!/usr/bin/env bash
# Guard that the python pixel tests are wired into an automated runner (ci-3aw).
#
# Before this wiring, mods/*/unit-tests/test_*.py (the from-space planet-art
# pixel tests, e.g. test_planet_maps.py + test_starmap_lighting.py) were run by
# NO runner: npm 'test:unit' globs only test_*.lua, so the python guards rotted
# silently. This asserts the fix stays in place:
#
#   1. A 'test:unit:py' npm script exists.
#   2. The top-level 'test' target invokes it (so CI/`npm test` runs it).
#   3. Running it actually DISCOVERS and executes every test_*.py under
#      mods/*/unit-tests, and cleanly SKIPS unit-tests dirs that have only lua
#      tests (the no-match glob guard), exiting 0 when they pass.
#
# Fails on main (no test:unit:py script -> `npm run` errors, jq checks fail).
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
PKG="$REPO/package.json"

fail() { echo "FAIL: $*" >&2; exit 1; }

[ -f "$PKG" ] || fail "no package.json at $PKG"

# --- 1. The dedicated python runner script exists -----------------------------
jq -e '.scripts["test:unit:py"]' "$PKG" >/dev/null \
  || fail "package.json has no 'test:unit:py' script"

# --- 2. The top-level 'test' target wires it in -------------------------------
jq -e '.scripts.test | test("test:unit:py")' "$PKG" >/dev/null \
  || fail "'test' target does not run 'test:unit:py'"

# --- 3. The runner discovers + runs every test_*.py, skipping lua-only dirs ----
# Collect the python tests the runner is expected to find, straight from disk.
mapfile -t PY_TESTS < <(cd "$REPO" && find mods -path '*/unit-tests/test_*.py' -type f | sort)
[ "${#PY_TESTS[@]}" -ge 1 ] \
  || fail "no test_*.py found under mods/*/unit-tests (nothing to guard)"

OUT=$(cd "$REPO" && npm run --silent test:unit:py 2>&1) \
  || { echo "$OUT" >&2; fail "test:unit:py exited non-zero"; }

# Every python test on disk must appear in the runner's output (proves discovery,
# not just that some subset ran).
for t in "${PY_TESTS[@]}"; do
  grep -qF "$t" <<<"$OUT" \
    || { echo "$OUT" >&2; fail "test:unit:py did not run $t"; }
done

# A unit-tests dir with only lua tests must not break the runner. cindra-start
# has exactly this shape today; assert the runner still exited clean above and
# did not choke on the empty test_*.py glob for it.
if [ -d "$REPO/mods/cindra-start/unit-tests" ] \
   && ! ls "$REPO"/mods/cindra-start/unit-tests/test_*.py >/dev/null 2>&1; then
  grep -qF "mods/cindra-start/unit-tests/test_*.py" <<<"$OUT" \
    && fail "test:unit:py leaked an unexpanded glob (missing no-match guard)"
fi

echo "PASS: test:unit:py discovers and runs ${#PY_TESTS[@]} python test(s), skips lua-only dirs"
