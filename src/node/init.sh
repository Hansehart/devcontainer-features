#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/hook.sh"

# Create the tool's cache and global prefix, then apply the requested config.
init_state() {
  if [ -n "${NPM_CONFIG_CACHE:-}" ]; then mkdir -p "$NPM_CONFIG_CACHE"; fi
  if [ -n "${NPM_CONFIG_PREFIX:-}" ]; then mkdir -p "$NPM_CONFIG_PREFIX"; fi
  apply_config requested-npmrc "${NPM_CONFIG_USERCONFIG:-$HOME/.npmrc}"
}

init_main node "$@"
