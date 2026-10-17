#!/usr/bin/env bash
set -euo pipefail

# Keep everything the hook creates private to the dev user.
umask 0077

# Read the feature's settings.
if [ -r /etc/profile.d/uv.sh ]; then . /etc/profile.d/uv.sh; fi

# Create the state dir on the mounted volume.
if [ -n "${UV_CACHE_DIR:-}" ]; then mkdir -p "${UV_CACHE_DIR%/*}"; fi

# Warn when the state dir sits on the container filesystem, since a volume is what keeps it
# across rebuilds; the create carries on.
state_dir="${UV_CACHE_DIR:+${UV_CACHE_DIR%/*}}"
if [ -n "$state_dir" ] && [ "$(stat -c %d "$state_dir")" = "$(stat -c %d /)" ]; then
  echo "uv: $state_dir is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
fi
