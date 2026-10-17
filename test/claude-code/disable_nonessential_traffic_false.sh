#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "nonessential traffic allowed" bash -lc '[ -z "${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-}" ]'

# Report result
reportResults
