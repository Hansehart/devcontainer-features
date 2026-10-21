#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Use a login shell, which reads the feature's profile.
check "claude on PATH" bash -lc "command -v claude"
check "claude version" bash -lc "claude --version"
check "nonessential traffic disabled by default" bash -lc '[ "$CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" = 1 ]'
# The requested settings sit with the feature's config.
check "requested settings in the feature's config dir" test -f /usr/local/etc/claude-code/requested-settings.json

# Report result
reportResults
