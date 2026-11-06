#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/hook.sh"

# Apply the requested config, with its escaped quotes and line breaks expanded.
init_state() {
  apply_config requested-config.toml "${CODEX_HOME:-$HOME/.codex}/config.toml"
}

init_main codex "$@"
