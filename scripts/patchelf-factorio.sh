#!/usr/bin/env bash
# Re-patchelf the Factorio binary so it finds its runtime libs on NixOS.
#
# The shipped Factorio binary has no RUNPATH (statically links SDL but
# dlopens libX11 / libXScrnSaver / libGL / etc. at runtime). On
# non-FHS systems like NixOS, the loader can't find those libs unless
# we either wrap with steam-run or bake nix-store paths into RUNPATH.
# This script does the latter so play.sh works standalone.
#
# Run this any time the binary is replaced (steam update, fresh
# extraction over the install dir, etc.) or when play.sh starts
# crashing in SDLWindow.cpp with "No available video device".
#
# Idempotent: re-running on an already-patched binary just rewrites
# the same RUNPATH. A timestamped backup is kept the first time.

set -euo pipefail

cd "$(dirname "$0")/.."

BIN=factorio/bin/x64/factorio
if [ ! -f "$BIN" ]; then
  echo "Factorio binary not found at $BIN" >&2
  exit 1
fi

if [ ! -f "$BIN.bak" ]; then
  cp -a "$BIN" "$BIN.bak"
  echo "Backed up to $BIN.bak"
fi

echo "Resolving nix-store paths for runtime libs (may build cold caches)..."
PATHS=$(nix build --no-link --print-out-paths \
  nixpkgs#alsa-lib \
  nixpkgs#libglvnd \
  nixpkgs#libpulseaudio \
  nixpkgs#libxkbcommon \
  nixpkgs#wayland \
  nixpkgs#xorg.libICE \
  nixpkgs#xorg.libSM \
  nixpkgs#xorg.libX11 \
  nixpkgs#xorg.libXcursor \
  nixpkgs#xorg.libXext \
  nixpkgs#xorg.libXi \
  nixpkgs#xorg.libXinerama \
  nixpkgs#xorg.libXrandr \
  nixpkgs#xorg.libXScrnSaver \
  nixpkgs#xorg.libXxf86vm \
  nixpkgs#xorg.libxcb)

# Drop -man / -dev / other sub-outputs, keep just the main store path
# per package and join with `/lib` suffix.
RPATH=$(echo "$PATHS" \
  | grep -vE '\-(man|dev|doc|info)$' \
  | sed 's|$|/lib|' \
  | paste -sd:)
RPATH="$RPATH:/run/opengl-driver/lib"

echo "Setting RUNPATH..."
nix shell nixpkgs#patchelf -c patchelf --set-rpath "$RPATH" "$BIN"

# Set the ELF interpreter to a CONCRETE nix-store glibc ld-linux, not
# the stock /lib64/ld-linux-x86-64.so.2 (which on NixOS is a nix-ld
# shim). This matters for the GRAPHICS path: SDL dlopen()s libX11 /
# libGL at runtime, and only a concrete glibc loader reliably honours
# the binary's DT_RUNPATH for those dlopens. Under the nix-ld shim the
# runtime dlopen misses the RUNPATH and SDL aborts with the misleading
# "No available video device" even though `--version` (no graphics)
# works fine. A fresh Factorio extraction ships the stock interpreter,
# so this step is REQUIRED after every re-extraction, not just the
# rpath fix above.
echo "Resolving nix-store glibc loader..."
# Prefer the concrete glibc ld-linux that the system's nix-ld symlink
# already points at (always matches the running glibc). Fall back to
# building glibc from nixpkgs and locating ld-linux under its lib dir
# (the default `nix build` output is `-bin`, so glob the store path).
LDSO=""
NIXLD_TARGET=$(readlink -f /run/current-system/sw/share/nix-ld/lib/ld.so 2>/dev/null || true)
if [ -n "$NIXLD_TARGET" ] && [ -e "$NIXLD_TARGET" ]; then
  LDSO="$NIXLD_TARGET"
else
  GLIBC=$(nix build --no-link --print-out-paths nixpkgs#glibc 2>/dev/null | head -1)
  # Strip any output suffix (-bin/-dev/...) to reach the main lib output.
  GLIBC_BASE="${GLIBC%-bin}"
  for cand in "$GLIBC/lib/ld-linux-x86-64.so.2" "$GLIBC_BASE/lib/ld-linux-x86-64.so.2"; do
    if [ -e "$cand" ]; then LDSO="$cand"; break; fi
  done
fi
if [ -n "$LDSO" ] && [ -e "$LDSO" ]; then
  echo "Setting interpreter to $LDSO ..."
  nix shell nixpkgs#patchelf -c patchelf --set-interpreter "$LDSO" "$BIN"
else
  echo "WARNING: could not resolve a concrete glibc ld-linux at $LDSO;" >&2
  echo "leaving interpreter as-is. Graphics may fail under nix-ld." >&2
fi

echo
echo "Done. Verify:"
echo "  interpreter: $(nix shell nixpkgs#patchelf -c patchelf --print-interpreter "$BIN")"
echo "  rpath:       $(nix shell nixpkgs#patchelf -c patchelf --print-rpath "$BIN")"
