#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Runs as a non-root remoteUser with UID remapping off so the build-time ownership holds.
check "state dir pre-created" test -d /var/claude-code
check "state dir owned by the dev user" bash -c '[ "$(stat -c %U /var/claude-code)" = "$(id -un)" ]'
check "state dir writable by the dev user" bash -c 'touch /var/claude-code/.probe && rm /var/claude-code/.probe'

# The test harness does not run the hook, so invoke it here.
/usr/local/share/claude-code/init.sh

check "CLAUDE_CONFIG_DIR exported" bash -lc '[ "$CLAUDE_CONFIG_DIR" = /var/claude-code ]'

# Report result
reportResults
