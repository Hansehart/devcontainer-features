#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 0.13.7" bash -c "uv --version | grep -qwF '0.13.7'"

# Report result
reportResults
