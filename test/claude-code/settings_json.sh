#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Run the hook as a container create does.
/usr/local/libexec/claude-code/init.sh

target="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
check "settings written" grep -qF '"defaultMode":"plan"' "$target"

# The hook owns the file, so a re-run restores the requested content.
printf '%s' '{"permissions":{"defaultMode":"bypassPermissions"}}' > "$target"
/usr/local/libexec/claude-code/init.sh
check "settings restored on re-run" grep -qF '"defaultMode":"plan"' "$target"

# Report result
reportResults
