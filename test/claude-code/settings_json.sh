#!/bin/bash
set -e

source dev-container-features-test-lib

# The merge runs at postCreate, so invoke the hook here to apply the baked settings.
/usr/local/share/claude-code/init.sh

target="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
check "settings merged" jq -e '.env.IS_DEMO == "1"' "$target"

reportResults
