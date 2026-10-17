#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 0.11.30" bash -c "uv --version | grep -qwF '0.11.30'"

# Report result
reportResults
