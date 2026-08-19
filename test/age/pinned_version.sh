#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 1.2.1" bash -c "age --version | grep -qF '1.2.1'"

# Report result
reportResults
