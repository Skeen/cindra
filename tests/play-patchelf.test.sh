#!/usr/bin/env bash
# play.sh must make a fresh 'nix develop + ./play.sh' work on NixOS by
# auto-patchelf'ing an unpatched Factorio binary (interpreter and/or RUNPATH)
# before launch, and by honoring FACTORIO_PATH / FACTORIO_DIR overrides.
#
# We can't run the real patcher here (it shells out to `nix build`), so we mock
# both sides of the mechanism:
#   * the `patchelf` play.sh uses to DETECT an unpatched binary (report a
#     nonexistent interpreter, so detection fires on any host, not just NixOS),
#   * the patcher play.sh RUNS (via PLAY_PATCHELF_CMD), asserting it is invoked
#     with the resolved binary path and that launch still proceeds afterward.
# It also checks the opt-out (PLAY_NO_PATCHELF=1) instructs instead of running,
# and that patchelf-factorio.sh honors its positional binary argument.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# --- Fake Factorio install (stub binary records its args, exits 0) -----------
INSTALL="$TMP/factorio"
mkdir -p "$INSTALL/bin/x64" "$INSTALL/mods"
cat > "$INSTALL/bin/x64/factorio" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$TMP/launch-args.txt"
exit 0
EOF
chmod +x "$INSTALL/bin/x64/factorio"
BIN_REAL=$(realpath "$INSTALL/bin/x64/factorio")

# --- Mocks -------------------------------------------------------------------
BINDIR="$TMP/bin"; mkdir -p "$BINDIR"

# Fake `patchelf` for DETECTION: report a nonexistent interpreter and empty
# RUNPATH so play.sh flags the binary as unpatched on any host.
cat > "$BINDIR/patchelf" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --print-interpreter) echo /nonexistent/ld-linux-x86-64.so.2 ;;
  --print-rpath)       echo "" ;;
  *)                   exit 0 ;;
esac
EOF
chmod +x "$BINDIR/patchelf"

# Fake patcher: record the target it was handed, exit 0.
cat > "$BINDIR/fake-patchelf-factorio.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\${1:-}" > "$TMP/patched-target.txt"
exit 0
EOF
chmod +x "$BINDIR/fake-patchelf-factorio.sh"

run_play() {  # extra env=val ... -> runs play.sh, stderr to $TMP/play.err
  cd "$REPO"
  env -u APS_PATH -u HELMOD_ZIP -u FACTORIO_DIR \
    PATH="$BINDIR:$PATH" \
    FACTORIO_PATH="$INSTALL/bin/x64/factorio" \
    PLAY_NO_FETCH=1 \
    PLAY_PATCHELF_CMD="$BINDIR/fake-patchelf-factorio.sh" \
    "$@" \
    ./play.sh >/dev/null 2>"$TMP/play.err"
}

# --- 1. Auto-patch then launch -----------------------------------------------
rm -f "$TMP/patched-target.txt" "$TMP/launch-args.txt"
run_play || { cat "$TMP/play.err" >&2; fail "play.sh exited non-zero on unpatched binary"; }

[ -f "$TMP/patched-target.txt" ] || fail "patcher was not auto-invoked for an unpatched binary"
target=$(cat "$TMP/patched-target.txt")
[ "$target" = "$BIN_REAL" ] \
  || fail "patcher got '$target', expected resolved binary '$BIN_REAL'"
grep -qx -- '--mod-directory' "$TMP/launch-args.txt" \
  || fail "factorio not launched after patching"

# --- 2. FACTORIO_DIR override is patched too ---------------------------------
rm -f "$TMP/patched-target.txt" "$TMP/launch-args.txt"
cd "$REPO"
env -u APS_PATH -u HELMOD_ZIP -u FACTORIO_PATH \
  PATH="$BINDIR:$PATH" \
  FACTORIO_DIR="$INSTALL" \
  PLAY_NO_FETCH=1 \
  PLAY_PATCHELF_CMD="$BINDIR/fake-patchelf-factorio.sh" \
  ./play.sh >/dev/null 2>"$TMP/play.err" \
  || { cat "$TMP/play.err" >&2; fail "play.sh exited non-zero with FACTORIO_DIR override"; }
[ "$(cat "$TMP/patched-target.txt" 2>/dev/null || true)" = "$BIN_REAL" ] \
  || fail "FACTORIO_DIR binary was not patched (got '$(cat "$TMP/patched-target.txt" 2>/dev/null)')"

# --- 3. PLAY_NO_PATCHELF=1 instructs instead of running ----------------------
rm -f "$TMP/patched-target.txt" "$TMP/launch-args.txt"
if run_play PLAY_NO_PATCHELF=1; then
  fail "play.sh should exit non-zero when unpatched and PLAY_NO_PATCHELF=1"
fi
[ -f "$TMP/patched-target.txt" ] && fail "patcher ran despite PLAY_NO_PATCHELF=1"
grep -q "patchelf-factorio.sh" "$TMP/play.err" \
  || fail "PLAY_NO_PATCHELF=1 did not instruct to run patchelf-factorio.sh"

# --- 4. patchelf-factorio.sh honors its positional binary arg ----------------
# (rejects a missing target before any nix work, proving the arg is wired.)
if scripts/patchelf-factorio.sh /no/such/binary >/dev/null 2>"$TMP/pe.err"; then
  fail "patchelf-factorio.sh should reject a missing binary argument"
fi
grep -q "not found" "$TMP/pe.err" \
  || fail "patchelf-factorio.sh missing-arg error message changed"

echo "PASS: play.sh auto-patchelfs unpatched binaries (incl. FACTORIO_DIR); opt-out instructs"
