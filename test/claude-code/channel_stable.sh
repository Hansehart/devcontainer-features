#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The stable channel installs; its version is opaque, so assert claude resolves and runs.
check "claude on PATH" bash -lc "command -v claude"
check "claude version" bash -lc "claude --version"

# Report result
reportResults
