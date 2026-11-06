#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 0.166.0" bash -lc "codex --version | grep -qwF '0.166.0'"

# Report result
reportResults
