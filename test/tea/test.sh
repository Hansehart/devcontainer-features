#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "tea on PATH" bash -c "command -v tea"
check "tea version" tea --version
# The settings sit with the feature's config.
check "settings in the feature's config dir" test -f /usr/local/etc/tea/config.env

# Report result
reportResults
