#!/usr/bin/env bash
# Launch Factorio with the cindra mod + bundled deps.
# The binary at factorio/bin/x64/factorio is patchelf'd for NixOS
# (interpreter + RUNPATH point at nix-store paths), so it runs
# without steam-run.
set -eu
cd "$(dirname "$0")"

# Guard: if the binary lost its RUNPATH (steam update, fresh extraction, etc.)
# SDL will crash deep in SDLWindow.cpp with the misleading "No available video
# device". Catch it here with a clear pointer to the fix.
if command -v readelf >/dev/null 2>&1 \
   && ! readelf -d factorio/bin/x64/factorio 2>/dev/null | grep -q 'R\(UN\)\?PATH'; then
  echo "Factorio binary has no RUNPATH; SDL will fail to find libX11/libXss/libGL." >&2
  echo "Re-patchelf it with: ./scripts/patchelf-factorio.sh" >&2
  exit 1
fi

MODS=mods-bundle
rm -rf "$MODS"   # wipe stale symlinks from earlier runs
mkdir -p "$MODS"
ln -sfn ../mods/cindra "$MODS/cindra"

# Wire any-planet-start (vendored under vendor/any-planet-start/) so cindra-start
# can register Cindra as a startable planet, and cindra-dev-default can default
# the planet-picker to Cindra — saves a click on `New Game`. The dev-default mod
# is strictly opt-in for shipping; toggling it in mod-list.json disables the
# default-override without affecting any real Cindra mechanics.
HAS_APS=0
if [ -d vendor/any-planet-start ]; then
  ln -sfn ../vendor/any-planet-start "$MODS/any-planet-start"
  ln -sfn ../mods/cindra-start "$MODS/cindra-start"
  ln -sfn ../mods/cindra-dev-default "$MODS/cindra-dev-default"
  HAS_APS=1
fi

# DLC mods (space-age, quality, elevated-rails) auto-load from factorio/data/ —
# don't symlink them here or you'll get "Duplicate mod" errors.

if [ "$HAS_APS" = 1 ]; then
  APS_LINES='    { "name": "any-planet-start", "enabled": true },
    { "name": "cindra-start", "enabled": true },
    { "name": "cindra-dev-default", "enabled": true },'
else
  APS_LINES=''
fi
# The optional APS block ends with a trailing comma, so cindra carries a comma
# and a DLC mod (space-age) is the guaranteed comma-free last entry. recycler is
# a required built-in DLC in 2.1 (quality / space-age depend on it).
cat > "$MODS/mod-list.json" <<JSON
{
  "mods": [
    { "name": "cindra", "enabled": true },
$APS_LINES
    { "name": "base", "enabled": true },
    { "name": "elevated-rails", "enabled": true },
    { "name": "quality", "enabled": true },
    { "name": "recycler", "enabled": true },
    { "name": "space-age", "enabled": true }
  ]
}
JSON

exec ./factorio/bin/x64/factorio --mod-directory "$MODS" "$@"
