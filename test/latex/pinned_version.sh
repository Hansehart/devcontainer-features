#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to TeX Live 2025" bash -c "latex --version | grep -qwF 'TeX Live 2025'"

# Report result
reportResults
