#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The daemon reads its settings from its user's config directory.
check "daemon.json no-new-privileges written" grep -qF '"no-new-privileges":true' "$HOME/.config/docker/daemon.json"

# Report result
reportResults
