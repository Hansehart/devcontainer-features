#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The patch floats, so assert the line only.
check "resolved the 1.26 line" bash -lc "go version | grep -qE ' go1\.26\.[0-9]+ '"

# Report result
reportResults
