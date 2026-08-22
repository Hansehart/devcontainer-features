#!/usr/bin/env bash
set -euo pipefail

# Prepare Claude's config once its volume is mounted.
if [ -r /etc/profile.d/claude-code.sh ]; then . /etc/profile.d/claude-code.sh; fi

# Create the state dir once its volume is mounted.
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then mkdir -p "${CLAUDE_CONFIG_DIR}"; fi

# Write the requested settings to settings.json (empty leaves the file untouched).
req=/usr/local/share/claude-code/requested-settings.json
if [ -s "$req" ]; then
  target="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  mkdir -p "$(dirname "$target")"
  printf '%s\n' "$(cat "$req")" > "$target"
fi
