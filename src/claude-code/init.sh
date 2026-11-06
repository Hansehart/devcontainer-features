#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/hook.sh"

# Apply the requested settings, kept verbatim as JSON.
init_state() {
  apply_config requested-settings.json "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" '%s'
}

init_main claude-code "$@"
