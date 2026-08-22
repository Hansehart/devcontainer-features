#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The test harness does not run the hook, so invoke it here to apply the baked settings.
/usr/local/share/claude-code/init.sh

target="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
check "settings written" grep -qF '"defaultMode":"plan"' "$target"

# The hook owns settings.json, so a re-run restores the requested settings.
printf '%s' '{"permissions":{"defaultMode":"bypassPermissions"}}' > "$target"
/usr/local/share/claude-code/init.sh
check "settings restored on re-run" grep -qF '"defaultMode":"plan"' "$target"

# Report result
reportResults
