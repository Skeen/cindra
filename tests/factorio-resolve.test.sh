#!/usr/bin/env bash
# Guard (ci-j340): every in-engine entrypoint must FIND a shared Factorio
# install from a bare worktree, and must FAIL LOUDLY when there is none.
#
# The bug: install discovery ended at the in-repo ./factorio symlink, and
# nothing in this repo ever creates that symlink. A fresh worktree therefore had
# no reachable engine, `cindra-test` aborted, and the work landed as "could not
# verify in-engine" -- with a perfectly good install sitting a few directories
# up. Verified stopped meaning verified.
#
# So we assert the two things a player-of-this-toolchain actually observes:
#   1. WHICH BINARY GETS RUN. Not the search order in the source -- the actual
#      exec. Every case builds a throwaway install tree with stub binaries that
#      record their own path when run, then asserts the right stub ran. No real
#      250MB install is involved, and the repo under test is a symlink farm in
#      /tmp so the host's own install cannot leak into the answer.
#   2. THAT A MISSING ENGINE IS FATAL. The integration entrypoint must exit
#      non-zero and seed nothing, so a run that never touched the engine cannot
#      be mistaken for a clean in-engine result.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

RAN="$TMP/ran.txt"     # every stub binary appends its own resolved path here
ARGS="$TMP/args.txt"   # ...and dumps its args here

# make_install <root> : a fake Factorio install whose binary records that it ran.
# A plain shell script is deliberate: play.sh's patchelf probe skips non-ELF
# stubs, so nothing tries to patch it.
make_install() {
  mkdir -p "$1/bin/x64" "$1/mods"
  cat > "$1/bin/x64/factorio" <<EOF
#!/usr/bin/env bash
cd "\$(dirname "\$0")" && printf '%s\n' "\$PWD/factorio" >> "$RAN"
printf '%s\n' "\$@" > "$ARGS"
exit 0
EOF
  chmod +x "$1/bin/x64/factorio"
}

# bin_of <install-root> : the path a stub in that install reports when it runs
# (symlink-free, matching what the stub prints).
bin_of() { (cd "$1/bin/x64" && printf '%s\n' "$PWD/factorio"); }

# make_repo <dir> : a stand-in for a cindra checkout at an arbitrary depth --
# the real play.sh / scripts / mods, symlinked. play.sh cd's to its own dirname,
# so it treats <dir> as the repo root and writes mods-bundle there, keeping the
# real repo untouched.
make_repo() {
  mkdir -p "$1"
  ln -sfn "$REPO/play.sh" "$1/play.sh"
  ln -sfn "$REPO/scripts" "$1/scripts"
  ln -sfn "$REPO/mods" "$1/mods"
}

# run_play <repo-dir> [env=val ...] : launch play.sh from that repo with a clean
# environment (no host FACTORIO_* / mod overrides, no network fetches).
run_play() {
  local dir=$1; shift
  : > "$RAN"
  (cd "$dir" && env -u APS_PATH -u HELMOD_ZIP -u FACTORIO_PATH -u FACTORIO_DIR \
      PLAY_NO_FETCH=1 "$@" ./play.sh) >/dev/null 2>"$TMP/play.err"
}

ran_binary() { tail -1 "$RAN" 2>/dev/null || true; }

# ---------------------------------------------------------------------------
# 1. A worktree several levels deep, with NO ./factorio of its own, still runs
#    the shared install found by walking up. This is the case that was broken.
# ---------------------------------------------------------------------------
WS="$TMP/ws"
make_install "$WS/factorio-patched"
DEEP="$WS/hq/cindra/polecats/minuteman/cindra"
make_repo "$DEEP"

run_play "$DEEP" || { cat "$TMP/play.err" >&2; fail "play.sh exited non-zero from a bare nested worktree"; }
[ "$(ran_binary)" = "$(bin_of "$WS/factorio-patched")" ] \
  || fail "nested worktree ran '$(ran_binary)', expected the shared install found upward"
grep -qx -- '--mod-directory' "$ARGS" || fail "the discovered binary was not launched with the mod bundle"

# ---------------------------------------------------------------------------
# 2. Where a parent holds both, the PATCHED install wins (on NixOS the unpatched
#    one cannot launch at all, so preferring it would be a silent trap).
# ---------------------------------------------------------------------------
make_install "$WS/factorio"
run_play "$DEEP" || { cat "$TMP/play.err" >&2; fail "play.sh exited non-zero with both installs present"; }
[ "$(ran_binary)" = "$(bin_of "$WS/factorio-patched")" ] \
  || fail "with both present, ran '$(ran_binary)', expected the factorio-patched one"

# ---------------------------------------------------------------------------
# 3. An in-repo ./factorio still beats the upward search: a deliberate per-clone
#    symlink must not be silently overridden by something further up.
# ---------------------------------------------------------------------------
make_install "$DEEP/factorio"
run_play "$DEEP" || { cat "$TMP/play.err" >&2; fail "play.sh exited non-zero with an in-repo install"; }
[ "$(ran_binary)" = "$(bin_of "$DEEP/factorio")" ] \
  || fail "in-repo ./factorio was not preferred (ran '$(ran_binary)')"

# ---------------------------------------------------------------------------
# 4./5. The explicit overrides keep winning over everything discovered.
# ---------------------------------------------------------------------------
OVERRIDE="$TMP/elsewhere/factorio"
make_install "$OVERRIDE"

run_play "$DEEP" FACTORIO_PATH="$OVERRIDE/bin/x64/factorio" \
  || { cat "$TMP/play.err" >&2; fail "play.sh exited non-zero with FACTORIO_PATH set"; }
[ "$(ran_binary)" = "$(bin_of "$OVERRIDE")" ] \
  || fail "FACTORIO_PATH lost to discovery (ran '$(ran_binary)')"

run_play "$DEEP" FACTORIO_DIR="$OVERRIDE" \
  || { cat "$TMP/play.err" >&2; fail "play.sh exited non-zero with FACTORIO_DIR set"; }
[ "$(ran_binary)" = "$(bin_of "$OVERRIDE")" ] \
  || fail "FACTORIO_DIR lost to discovery (ran '$(ran_binary)')"

# ---------------------------------------------------------------------------
# 6. With no engine anywhere, nothing runs and the exit is non-zero.
#    The search reaches / , so a stray install above TMPDIR would satisfy it --
#    check for that and say so loudly rather than assert something false.
# ---------------------------------------------------------------------------
BARE="$TMP/bare/a/b/c/cindra"
make_repo "$BARE"

stray=""
d=$(dirname "$TMP")
while :; do
  p=${d%/}
  for n in factorio-patched factorio; do
    [ -x "$p/$n/bin/x64/factorio" ] && stray="$p/$n"
  done
  [ "$d" = "/" ] && break
  d=$(dirname "$d")
done

if [ -n "$stray" ]; then
  echo "WARNING: skipping the no-engine cases: this host has a real install at $stray," >&2
  echo "         above TMPDIR, so the upward search legitimately finds one." >&2
else
  if run_play "$BARE"; then
    fail "play.sh exited ZERO with no engine anywhere -- a missing engine must be fatal"
  fi
  [ -z "$(ran_binary)" ] || fail "something was launched with no engine present"
  grep -qi "no factorio engine found" "$TMP/play.err" \
    || { cat "$TMP/play.err" >&2; fail "the no-engine failure is not self-explanatory"; }

  # The INTEGRATION entrypoint is the one that matters most: it must refuse to
  # run, and must not even seed its data dir, so there is no half-finished run
  # to mistake for a verified one.
  DD="$TMP/no-engine-data-dir"
  mkdir -p "$TMP/ftmod"
  printf '{ "name": "factorio-test", "version": "3.1.1" }\n' > "$TMP/ftmod/info.json"
  if (cd "$BARE" && env -u FACTORIO_PATH -u FACTORIO_DIR \
        FACTORIO_TEST_MOD="$TMP/ftmod" FACTORIO_TEST_DATA_DIR="$DD" \
        ./scripts/cindra-test.sh) >/dev/null 2>"$TMP/ct.err"; then
    fail "the integration entrypoint exited ZERO with no engine -- in-engine results would be unverifiable"
  fi
  grep -qi "no factorio engine found" "$TMP/ct.err" \
    || { cat "$TMP/ct.err" >&2; fail "the integration entrypoint's no-engine message is not self-explanatory"; }
  [ ! -e "$DD" ] || fail "the integration entrypoint seeded its data dir despite having no engine"
fi

# ---------------------------------------------------------------------------
# 7. And the positive integration case: from a bare nested worktree, the runner
#    hands the CLI the engine it discovered upward (with a stub CLI standing in
#    for factorio-test, so no game actually boots).
# ---------------------------------------------------------------------------
RUNNER_REPO="$WS/hq/cindra/polecats/other/cindra"
make_repo "$RUNNER_REPO"
mkdir -p "$RUNNER_REPO/node_modules/.bin"
cat > "$RUNNER_REPO/node_modules/.bin/factorio-test" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$TMP/cli-args.txt"
exit 0
EOF
chmod +x "$RUNNER_REPO/node_modules/.bin/factorio-test"

DD2="$TMP/data-dir"
(cd "$RUNNER_REPO" && env -u FACTORIO_PATH -u FACTORIO_DIR \
    FACTORIO_TEST_MOD="$TMP/ftmod" FACTORIO_TEST_DATA_DIR="$DD2" \
    ./scripts/cindra-test.sh) >/dev/null 2>"$TMP/ct2.err" \
  || { cat "$TMP/ct2.err" >&2; fail "the integration entrypoint failed from a bare nested worktree"; }

# --factorio-path <binary> must be the install discovered by walking up.
want=$(bin_of "$WS/factorio-patched")
got=$(grep -A1 -x -- '--factorio-path' "$TMP/cli-args.txt" | tail -1)
[ "$(cd "$(dirname "$got")" && pwd)/$(basename "$got")" = "$want" ] \
  || fail "the runner handed the CLI '$got', expected the discovered '$want'"
[ -e "$DD2/mods/factorio-test_3.1.1" ] || fail "factorio-test mod was not seeded into the data dir"
[ -e "$DD2/mods/env-scanner" ] || fail "env-scanner was not seeded into the data dir"

echo "PASS: play.sh + the integration runner find a shared install from any depth, and a missing engine is fatal"
