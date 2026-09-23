#!/usr/bin/env bash
set -euo pipefail

# Create for the dev user alone, matching the state dir the hook writes into.
umask 0077

# Prepare Claude's config once the volume is mounted.
if [ -r /etc/profile.d/claude-code.sh ]; then . /etc/profile.d/claude-code.sh; fi

# Create the state dir once the volume is mounted.
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then mkdir -p "${CLAUDE_CONFIG_DIR}"; fi

# A state dir sharing a filesystem with / holds its contents in the container, which goes at
# the next rebuild. Report it after the mkdir, and let the create carry on.
state_dir="${CLAUDE_CONFIG_DIR:-}"
if [ -n "$state_dir" ] && [ "$(stat -c %d "$state_dir")" = "$(stat -c %d /)" ]; then
  echo "claude-code: $state_dir is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
fi

# Write the requested settings to settings.json (empty leaves the file untouched).
req=/usr/local/share/claude-code/requested-settings.json
if [ -s "$req" ]; then
  target="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  mkdir -p "$(dirname "$target")"
  printf '%s\n' "$(cat "$req")" > "$target"
fi
