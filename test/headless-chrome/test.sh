#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "chrome-headless-shell on PATH" bash -c "command -v chrome-headless-shell"
check "chrome-headless-shell version" chrome-headless-shell --version

# Report result
reportResults
