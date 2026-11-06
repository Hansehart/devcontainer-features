#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 26.13.0" bash -c "node --version | grep -qwF 'v26.13.0'"

# Report result
reportResults
