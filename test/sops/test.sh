#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "sops on PATH" bash -c "command -v sops"
check "sops version" sops --version --disable-version-check

# Report result
reportResults
