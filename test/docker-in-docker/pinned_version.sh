#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 28.x" bash -c "docker --version | grep -q 'version 28\.'"

# Report result
reportResults
