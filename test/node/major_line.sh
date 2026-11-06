#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The patch floats, so assert the line only.
check "resolved the 24 line" bash -c "node --version | grep -qE '^v24\.'"
# The line follows its releases alone, so its version carries no prerelease suffix.
check "resolved a release in the line" bash -c "node --version | grep -qE '^v24\.[0-9]+\.[0-9]+$'"

# Report result
reportResults
