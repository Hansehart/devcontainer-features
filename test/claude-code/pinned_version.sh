#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 2.1.231" bash -lc "claude --version | grep -qF '2.1.231'"

# Report result
reportResults
