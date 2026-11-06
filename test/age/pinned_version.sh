#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 1.3.2" bash -c "age --version | grep -qwF 'v1.3.2'"

# Report result
reportResults
