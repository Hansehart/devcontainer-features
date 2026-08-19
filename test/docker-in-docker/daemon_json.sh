#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "daemon.json dns merged" jq -e '.dns[0] == "10.10.0.2"' /etc/docker/daemon.json

# Report result
reportResults
