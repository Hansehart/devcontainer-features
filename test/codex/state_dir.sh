#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Runs as a non-root remoteUser with UID remapping off so the build-time ownership holds.
check "state dir pre-created" test -d /var/codex
check "state dir owned by the dev user" bash -c '[ "$(stat -c %U /var/codex)" = "$(id -un)" ]'
check "state dir writable by the dev user" bash -c 'touch /var/codex/.probe && rm /var/codex/.probe'

# The test harness does not run the hook, so invoke it here.
/usr/local/share/codex/init.sh

check "CODEX_HOME exported" bash -lc '[ "$CODEX_HOME" = /var/codex ]'
# The binary still resolves now that CODEX_HOME points away from the payload.
check "codex runs against the state dir" bash -lc "codex --version"

# Report result
reportResults
