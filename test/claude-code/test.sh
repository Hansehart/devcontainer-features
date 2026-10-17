#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Use a login shell, which reads the feature's profile.
check "claude on PATH" bash -lc "command -v claude"
check "claude version" bash -lc "claude --version"
check "nonessential traffic disabled by default" bash -lc '[ "$CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" = 1 ]'

# Report result
reportResults
