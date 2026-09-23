#!/usr/bin/env bash
set -euo pipefail

# Create for the dev user alone, matching the state dir the hook writes into.
umask 0077

# Prepare npm's config once the volume is mounted.
if [ -r /etc/profile.d/node.sh ]; then . /etc/profile.d/node.sh; fi

# Create npm's cache and global prefix once the volume is mounted.
if [ -n "${NPM_CONFIG_CACHE:-}" ]; then mkdir -p "${NPM_CONFIG_CACHE}"; fi
if [ -n "${NPM_CONFIG_PREFIX:-}" ]; then mkdir -p "${NPM_CONFIG_PREFIX}"; fi

# A state dir sharing a filesystem with / holds its contents in the container, which goes at
# the next rebuild. Report it after the mkdir, and let the create carry on.
state_dir="${NPM_CONFIG_CACHE:+${NPM_CONFIG_CACHE%/*}}"
if [ -n "$state_dir" ] && [ "$(stat -c %d "$state_dir")" = "$(stat -c %d /)" ]; then
  echo "node: $state_dir is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
fi

# Write the requested config to .npmrc (empty leaves the file untouched).
req=/usr/local/share/node/requested-npmrc
if [ -s "$req" ]; then
  target="${NPM_CONFIG_USERCONFIG:-$HOME/.npmrc}"
  mkdir -p "$(dirname "$target")"
  printf '%b\n' "$(cat "$req")" > "$target"
fi
