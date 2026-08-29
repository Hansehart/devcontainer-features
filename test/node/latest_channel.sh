#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The channel floats, so the build is the assertion: an unresolvable tag fails the install.
check "resolved release runs" bash -lc "node --version"

# Report result
reportResults
