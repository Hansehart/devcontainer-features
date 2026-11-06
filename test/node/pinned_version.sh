#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 22.23.4" bash -c "node --version | grep -qwF 'v22.23.4'"

# Report result
reportResults
