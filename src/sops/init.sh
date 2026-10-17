#!/usr/bin/env bash
set -euo pipefail

# Keep everything the hook creates private to the dev user.
umask 0077

# Read the feature's settings.
if [ -r /etc/profile.d/sops.sh ]; then . /etc/profile.d/sops.sh; fi

# Create the state dir on the mounted volume.
if [ -n "${SOPS_AGE_KEY_FILE:-}" ]; then mkdir -p "${SOPS_AGE_KEY_FILE%/*}"; fi

# Warn when the state dir sits on the container filesystem, since a volume is what keeps it
# across rebuilds; the create carries on.
state_dir="${SOPS_AGE_KEY_FILE:+${SOPS_AGE_KEY_FILE%/*}}"
if [ -n "$state_dir" ] && [ "$(stat -c %d "$state_dir")" = "$(stat -c %d /)" ]; then
  echo "sops: $state_dir is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
fi
