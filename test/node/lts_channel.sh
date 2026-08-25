#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The channel floats, so assert the property that identifies it: Node only ever promotes
# even-numbered majors to LTS, so an odd major means the wrong line was resolved.
check "resolved an LTS line" bash -c "node --version | grep -qE '^v[0-9]*[02468]\.'"

# Report result
reportResults
