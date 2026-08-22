#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "daemon.json no-new-privileges written" grep -qF '"no-new-privileges":true' /etc/docker/daemon.json

# Report result
reportResults
