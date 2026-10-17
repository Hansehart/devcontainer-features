#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The channel floats, so a successful build is the assertion.
check "resolved release runs" bash -lc "node --version"

# Report result
reportResults
