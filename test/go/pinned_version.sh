#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 1.27.3" bash -lc "go version | grep -qwF 'go1.27.3'"

# Report result
reportResults
