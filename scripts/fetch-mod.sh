#!/usr/bin/env bash
# Download a mod release zip from the Factorio mod portal into a cache dir.
#
# Playtesting Cindra's start chain needs Any-Planet-Start (and Helmod is nice
# for recipe math), but neither is vendored in this repo: APS is deliberately an
# OPTIONAL external dependency (see AGENTS.md / SETUP.md), and Helmod is a large
# third-party mod. play.sh calls this as a last-resort fallback when it can't
# find a local copy, dropping the zip into a gitignored cache so the next launch
# reuses it instead of re-downloading.
#
# Auth: the mod-portal download endpoint needs a factorio.com service token.
# We read `service-username` / `service-token` from the Factorio install's
# player-data.json (the same creds the game itself uses), so a logged-in install
# just works. No token -> we bail with a clear message and play.sh continues
# with that mod disabled.
#
# Usage:
#   scripts/fetch-mod.sh <mod-name> <factorio-root> <cache-dir> [factorio-version]
#
# Prints the absolute path of the downloaded (or already-cached) zip on stdout.
set -euo pipefail

MOD_NAME=${1:?usage: fetch-mod.sh <mod-name> <factorio-root> <cache-dir> [factorio-version]}
FACTORIO_ROOT=${2:?missing factorio-root}
CACHE_DIR=${3:?missing cache-dir}
WANT_VERSION=${4:-2.1}

log() { echo "fetch-mod: $*" >&2; }

# Reuse a cached copy if we already have one (any version of this mod).
mkdir -p "$CACHE_DIR"
# shellcheck disable=SC2012  # mod filenames are controlled (name_version.zip)
cached=$(ls "$CACHE_DIR/${MOD_NAME}"_*.zip 2>/dev/null | sort -V | tail -1 || true)
if [ -n "$cached" ]; then
  log "using cached $(basename "$cached")"
  realpath "$cached"
  exit 0
fi

for tool in curl jq; do
  command -v "$tool" >/dev/null 2>&1 || { log "need '$tool' on PATH to fetch $MOD_NAME"; exit 1; }
done

PLAYER_DATA="$FACTORIO_ROOT/player-data.json"
if [ ! -f "$PLAYER_DATA" ]; then
  log "no player-data.json at $PLAYER_DATA; can't authenticate mod download"
  exit 1
fi
username=$(jq -r '.["service-username"] // empty' "$PLAYER_DATA")
token=$(jq -r '.["service-token"] // empty' "$PLAYER_DATA")
if [ -z "$username" ] || [ -z "$token" ]; then
  log "player-data.json has no service-username/token (log into factorio.com in-game first)"
  exit 1
fi

# Ask the portal for every release, then pick the newest one whose declared
# factorio_version matches what we want (major.minor, e.g. 2.1).
api="https://mods.factorio.com/api/mods/${MOD_NAME}/full"
log "querying $api"
meta=$(curl -fsSL "$api") || { log "mod portal query failed for $MOD_NAME"; exit 1; }

release=$(printf '%s' "$meta" | jq -c \
  --arg v "$WANT_VERSION" \
  '[.releases[] | select(.info_json.factorio_version == $v)] | sort_by(.released_at) | last // empty')
if [ -z "$release" ] || [ "$release" = "null" ]; then
  # Fall back to the newest release of any version rather than failing outright.
  release=$(printf '%s' "$meta" | jq -c '.releases | sort_by(.released_at) | last // empty')
  log "no release for factorio $WANT_VERSION; falling back to newest available"
fi
if [ -z "$release" ] || [ "$release" = "null" ]; then
  log "$MOD_NAME has no downloadable releases"
  exit 1
fi

version=$(printf '%s' "$release" | jq -r '.version')
dl_path=$(printf '%s' "$release" | jq -r '.download_url')
out="$CACHE_DIR/${MOD_NAME}_${version}.zip"

log "downloading $MOD_NAME $version"
curl -fsSL "https://mods.factorio.com${dl_path}?username=${username}&token=${token}" -o "$out.part" \
  || { log "download failed for $MOD_NAME $version"; rm -f "$out.part"; exit 1; }
mv -f "$out.part" "$out"
log "saved $(basename "$out")"
realpath "$out"
