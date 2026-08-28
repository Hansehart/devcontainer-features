#!/usr/bin/env bash
set -euo pipefail

# Prepare npm's config once the volume is mounted.
if [ -r /etc/profile.d/node.sh ]; then . /etc/profile.d/node.sh; fi

# Create npm's cache and global prefix once the volume is mounted.
if [ -n "${NPM_CONFIG_CACHE:-}" ]; then mkdir -p "${NPM_CONFIG_CACHE}"; fi
if [ -n "${NPM_CONFIG_PREFIX:-}" ]; then mkdir -p "${NPM_CONFIG_PREFIX}"; fi

# Write the requested config to .npmrc (empty leaves the file untouched).
req=/usr/local/share/node/requested-npmrc
if [ -s "$req" ]; then
  target="${NPM_CONFIG_USERCONFIG:-$HOME/.npmrc}"
  mkdir -p "$(dirname "$target")"
  printf '%b\n' "$(cat "$req")" > "$target"
fi
