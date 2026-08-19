#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to TeX Live 2024" bash -c "latex --version | grep -qF 'TeX Live 2024'"

# Report result
reportResults
