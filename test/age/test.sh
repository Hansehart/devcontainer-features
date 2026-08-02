#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "age on PATH" bash -c "command -v age"
check "age version" age --version
check "age-keygen on PATH" bash -c "command -v age-keygen"

# Report result
reportResults
