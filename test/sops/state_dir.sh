#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Runs as a non-root remoteUser, which the CLI may remap to a different UID at build time.
check "state dir pre-created" test -d /var/sops
check "dev user in the state dir group" bash -c 'id -nG | grep -qw sops'
check "state dir writable by the dev user" bash -c 'touch /var/sops/.probe && rm /var/sops/.probe'

# The test harness does not run the hook, so invoke it here.
/usr/local/share/sops/init.sh

check "SOPS_AGE_KEY_FILE exported" bash -lc '[ "$SOPS_AGE_KEY_FILE" = /var/sops/keys.txt ]'

# Report result
reportResults
