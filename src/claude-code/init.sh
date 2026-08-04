#!/usr/bin/env bash
set -euo pipefail

# postCreate hook: create the state dir once the volume is mounted.
if [ -r /etc/profile.d/claude-code.sh ]; then . /etc/profile.d/claude-code.sh; fi
[ -n "${CLAUDE_CONFIG_DIR:-}" ] || exit 0
mkdir -p "${CLAUDE_CONFIG_DIR}"
