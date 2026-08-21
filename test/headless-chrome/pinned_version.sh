#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 152.0.7977.42" bash -c "chrome-headless-shell --version | grep -qF '152.0.7977.42'"

# Report result
reportResults
