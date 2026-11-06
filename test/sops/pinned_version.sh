#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 3.13.3" bash -c "sops --version --disable-version-check | grep -qwF '3.13.3'"

# Report result
reportResults
