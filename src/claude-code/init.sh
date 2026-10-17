#!/usr/bin/env bash
set -euo pipefail

# Keep everything the hook creates private to the dev user.
umask 0077

# Read the feature's settings.
if [ -r /etc/profile.d/claude-code.sh ]; then . /etc/profile.d/claude-code.sh; fi

# Create the state dir on the mounted volume.
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then mkdir -p "${CLAUDE_CONFIG_DIR}"; fi

# Warn when the state dir sits on the container filesystem, since a volume is what keeps it
# across rebuilds; the create carries on.
state_dir="${CLAUDE_CONFIG_DIR:-}"
if [ -n "$state_dir" ] && [ "$(stat -c %d "$state_dir")" = "$(stat -c %d /)" ]; then
  echo "claude-code: $state_dir is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
fi

# Apply the requested settings, when there are any.
req=/usr/local/share/claude-code/requested-settings.json
if [ -s "$req" ]; then
  target="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  mkdir -p "$(dirname "$target")"
  printf '%s\n' "$(cat "$req")" > "$target"
fi
