#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The rootless daemon reads its settings from the remote user's config directory.
check "daemon.json no-new-privileges written" grep -qF '"no-new-privileges":true' "$HOME/.config/docker/daemon.json"

# Report result
reportResults
