#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 2.1.318" bash -lc "claude --version | grep -qwF '2.1.318'"

# Report result
reportResults
