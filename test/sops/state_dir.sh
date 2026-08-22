#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Runs as a non-root remoteUser with UID remapping off so the build-time ownership holds.
check "state dir pre-created" test -d /var/sops
check "state dir owned by the dev user" bash -c '[ "$(stat -c %U /var/sops)" = "$(id -un)" ]'
check "state dir writable by the dev user" bash -c 'touch /var/sops/.probe && rm /var/sops/.probe'

# The test harness does not run the hook, so invoke it here.
/usr/local/share/sops/init.sh

check "SOPS_AGE_KEY_FILE exported" bash -lc '[ "$SOPS_AGE_KEY_FILE" = /var/sops/keys.txt ]'

# Report result
reportResults
