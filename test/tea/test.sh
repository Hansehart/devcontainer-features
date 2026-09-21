#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "tea on PATH" bash -c "command -v tea"
check "tea version" tea --version

# Report result
reportResults
