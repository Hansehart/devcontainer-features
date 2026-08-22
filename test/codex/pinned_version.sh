#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 0.148.0" bash -lc "codex --version | grep -qF '0.148.0'"

# Report result
reportResults
