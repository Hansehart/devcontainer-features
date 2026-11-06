#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 157.0.8103.38" bash -c "chrome-headless-shell --version | grep -qwF '157.0.8103.38'"

# Report result
reportResults
