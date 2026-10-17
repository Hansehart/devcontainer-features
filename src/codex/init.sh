#!/usr/bin/env bash
set -euo pipefail

# Keep everything the hook creates private to the dev user.
umask 0077

# Read the feature's settings.
if [ -r /etc/profile.d/codex.sh ]; then . /etc/profile.d/codex.sh; fi

# Create the state dir on the mounted volume, where the tool expects it.
if [ -n "${CODEX_HOME:-}" ]; then mkdir -p "${CODEX_HOME}"; fi

# Warn when the state dir sits on the container filesystem, since a volume is what keeps it
# across rebuilds; the create carries on.
state_dir="${CODEX_HOME:-}"
if [ -n "$state_dir" ] && [ "$(stat -c %d "$state_dir")" = "$(stat -c %d /)" ]; then
  echo "codex: $state_dir is on the container filesystem; mount a volume there to keep it across rebuilds" >&2
fi

# Apply the requested config, when there is one.
req=/usr/local/share/codex/requested-config.toml
if [ -s "$req" ]; then
  target="${CODEX_HOME:-$HOME/.codex}/config.toml"
  mkdir -p "$(dirname "$target")"
  printf '%b\n' "$(cat "$req")" > "$target"
fi
