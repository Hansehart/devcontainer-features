#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The patch floats, so assert the line only.
check "resolved the 24 line" bash -c "node --version | grep -qE '^v24\.'"

# Report result
reportResults
