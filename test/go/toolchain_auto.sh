#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "toolchain set to auto" bash -lc '[ "$(go env GOTOOLCHAIN)" = auto ]'

# Report result
reportResults
