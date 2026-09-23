#!/usr/bin/env bash
set -euo pipefail

# Prepare sops's state once the volume is mounted.
if [ -r /etc/profile.d/sops.sh ]; then . /etc/profile.d/sops.sh; fi

# Create the state dir once the volume is mounted (the age key file names it).
if [ -n "${SOPS_AGE_KEY_FILE:-}" ]; then mkdir -p "${SOPS_AGE_KEY_FILE%/*}"; fi

# A state dir sharing a filesystem with / holds its contents in the container, which goes at
# the next rebuild. Report it after the mkdir, and let the create carry on.
state_dir="${SOPS_AGE_KEY_FILE:+${SOPS_AGE_KEY_FILE%/*}}"
if [ -n "$state_dir" ] && [ "$(stat -c %d "$state_dir")" = "$(stat -c %d /)" ]; then
  echo "sops: $state_dir is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
fi
