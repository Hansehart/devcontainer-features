#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The channel floats, so a successful build is the assertion.
check "resolved release runs" bash -lc "node --version"
# The channel follows releases alone, so its version carries no prerelease suffix.
check "resolved a release" bash -lc 'node --version | grep -qE "^v[0-9]+\.[0-9]+\.[0-9]+$"'

# Report result
reportResults
