#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "pinned to 3.13.0" bash -c "sops --version --disable-version-check | grep -qF '3.13.0'"

# Report result
reportResults
