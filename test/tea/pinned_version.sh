#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 0.15.1" bash -c "tea --version | grep -qF '0.15.1'"

# Report result
reportResults
