#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Strip the color codes the tool prints around its version.
check "pinned to 0.15.1" bash -c "tea --version | sed 's/\x1b\[[0-9;]*m//g' | grep -qwF '0.15.1'"

# Report result
reportResults
