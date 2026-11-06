#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "tea on PATH" bash -c "command -v tea"
check "tea version" tea --version
# The settings sit with the feature's config.
check "the state dir recorded for the hook" test -f /usr/local/etc/tea/state-dir
check "no separate settings file beside the record" test ! -e /usr/local/etc/tea/config.env

# Report result
reportResults
