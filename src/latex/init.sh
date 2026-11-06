#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/hook.sh"

# Create the user's trees on the mounted volume.
init_state() {
  if [ -n "${TEXMFHOME:-}" ]; then mkdir -p "$TEXMFHOME" "$TEXMFVAR" "$TEXMFCONFIG"; fi
}

init_main latex "$@"
