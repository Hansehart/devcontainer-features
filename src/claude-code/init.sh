#!/usr/bin/env bash
set -euo pipefail

# postCreate hook: prepare Claude's config once its volume is mounted.
if [ -r /etc/profile.d/claude-code.sh ]; then . /etc/profile.d/claude-code.sh; fi

# Create the state dir once its volume is mounted.
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then mkdir -p "${CLAUDE_CONFIG_DIR}"; fi

# Merge the requested settings into settings.json (empty leaves it untouched).
req=/usr/local/share/claude-code/requested-settings.json
if [ -s "$req" ]; then
  target="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  mkdir -p "$(dirname "$target")"
  prev='{}'
  if [ -f "$target" ]; then prev="$(cat "$target")"; fi
  printf '%s' "$prev" | jq --argjson add "$(cat "$req")" '. + $add' > "$target"
fi
