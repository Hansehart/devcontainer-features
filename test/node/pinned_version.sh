#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 22.11.0" bash -c "node --version | grep -qF 'v22.11.0'"

# Report result
reportResults
