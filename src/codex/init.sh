#!/usr/bin/env bash
set -euo pipefail

# Prepare Codex's config once the volume is mounted.
if [ -r /etc/profile.d/codex.sh ]; then . /etc/profile.d/codex.sh; fi

# Create the state dir once the volume is mounted (Codex errors on a missing CODEX_HOME).
if [ -n "${CODEX_HOME:-}" ]; then mkdir -p "${CODEX_HOME}"; fi

# A state dir sharing a filesystem with / holds its contents in the container, which goes at
# the next rebuild. Report it after the mkdir, and let the create carry on.
state_dir="${CODEX_HOME:-}"
if [ -n "$state_dir" ] && [ "$(stat -c %d "$state_dir")" = "$(stat -c %d /)" ]; then
  echo "codex: $state_dir is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
fi

# Write the requested config to config.toml (empty leaves the file untouched).
req=/usr/local/share/codex/requested-config.toml
if [ -s "$req" ]; then
  target="${CODEX_HOME:-$HOME/.codex}/config.toml"
  mkdir -p "$(dirname "$target")"
  printf '%b\n' "$(cat "$req")" > "$target"
fi
