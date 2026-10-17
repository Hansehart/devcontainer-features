#!/usr/bin/env bash
set -euo pipefail

# Keep everything the hook creates private to the dev user.
umask 0077

# Read the feature's settings.
if [ -r /etc/profile.d/node.sh ]; then . /etc/profile.d/node.sh; fi

# Create npm's cache and global prefix on the mounted volume.
if [ -n "${NPM_CONFIG_CACHE:-}" ]; then mkdir -p "${NPM_CONFIG_CACHE}"; fi
if [ -n "${NPM_CONFIG_PREFIX:-}" ]; then mkdir -p "${NPM_CONFIG_PREFIX}"; fi

# Warn when the state dir sits on the container filesystem, since a volume is what keeps it
# across rebuilds; the create carries on.
state_dir="${NPM_CONFIG_CACHE:+${NPM_CONFIG_CACHE%/*}}"
if [ -n "$state_dir" ] && [ "$(stat -c %d "$state_dir")" = "$(stat -c %d /)" ]; then
  echo "node: $state_dir is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
fi

# Apply the requested config, when there is one.
req=/usr/local/share/node/requested-npmrc
if [ -s "$req" ]; then
  target="${NPM_CONFIG_USERCONFIG:-$HOME/.npmrc}"
  mkdir -p "$(dirname "$target")"
  printf '%b\n' "$(cat "$req")" > "$target"
fi
