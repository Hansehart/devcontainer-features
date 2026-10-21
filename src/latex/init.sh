#!/usr/bin/env bash
set -euo pipefail

# Keep everything the hook creates private to the dev user.
umask 0077

# Read the feature's settings.
if [ -r /etc/profile.d/latex.sh ]; then . /etc/profile.d/latex.sh; fi

# Create the user's trees on the mounted volume.
if [ -n "${TEXMFHOME:-}" ]; then mkdir -p "$TEXMFHOME" "$TEXMFVAR" "$TEXMFCONFIG"; fi

# Warn when the state dir sits on the container filesystem, since a volume is what keeps it
# across rebuilds; the create carries on.
state_dir="${TEXMFHOME:+${TEXMFHOME%/*}}"
if [ -n "$state_dir" ] && [ "$(stat -c %d "$state_dir")" = "$(stat -c %d /)" ]; then
  echo "latex: $state_dir is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
fi
