#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 28.x" bash -c "docker --version | grep -q 'version 28\.'"
check "buildx pinned to 0.17.x" bash -c "docker buildx version | grep -q ' v0\.17\.'"
check "compose pinned to 2.29.x" bash -c "docker compose version | grep -q 'v2\.29\.'"

# Report result
reportResults
