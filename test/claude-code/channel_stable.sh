#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The stable channel picks the current release, so assert claude installs and runs.
check "claude on PATH" bash -lc "command -v claude"
check "claude version" bash -lc "claude --version"

# Report result
reportResults
