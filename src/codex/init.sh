#!/usr/bin/env bash
set -euo pipefail

# Prepare Codex's config once its volume is mounted.
if [ -r /etc/profile.d/codex.sh ]; then . /etc/profile.d/codex.sh; fi

# Create the state dir once its volume is mounted (Codex errors on a missing CODEX_HOME).
if [ -n "${CODEX_HOME:-}" ]; then mkdir -p "${CODEX_HOME}"; fi

# Write the requested config to config.toml (empty leaves the file untouched).
req=/usr/local/share/codex/requested-config.toml
if [ -s "$req" ]; then
  target="${CODEX_HOME:-$HOME/.codex}/config.toml"
  mkdir -p "$(dirname "$target")"
  printf '%b\n' "$(cat "$req")" > "$target"
fi
