#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The channel floats, so the build itself is the assertion: resolving the newest release
# reads the whole index, and a mistake there fails the install before this script runs.
check "resolved a release" bash -c "node --version | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'"

# Report result
reportResults
