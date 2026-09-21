#!/usr/bin/env bash
set -euo pipefail

# Prepare uv's state once the volume is mounted.
if [ -r /etc/profile.d/uv.sh ]; then . /etc/profile.d/uv.sh; fi

# Create the state dir once the volume is mounted (the cache dir names it).
if [ -n "${UV_CACHE_DIR:-}" ]; then mkdir -p "${UV_CACHE_DIR%/*}"; fi

# A state dir sharing a filesystem with / holds its contents in the container, which goes at
# the next rebuild. Report it after the mkdir, and let the create carry on.
state_dir="${UV_CACHE_DIR:+${UV_CACHE_DIR%/*}}"
if [ -n "$state_dir" ] && [ "$(stat -c %d "$state_dir")" = "$(stat -c %d /)" ]; then
  echo "uv: $state_dir is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
fi
