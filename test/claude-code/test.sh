#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Use a login shell so the profile.d snippet adding ~/.local/bin to PATH is sourced.
check "claude on PATH" bash -lc "command -v claude"
check "claude version" bash -lc "claude --version"

# Report result
reportResults
