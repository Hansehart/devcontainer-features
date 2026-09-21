#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Runs as a non-root remoteUser, which the CLI may remap to a different UID at build time.
check "state dir pre-created" test -d /var/codex
check "dev user in the state dir group" bash -c 'id -nG | grep -qw codex'
check "state dir writable by the dev user" bash -c 'touch /var/codex/.probe && rm /var/codex/.probe'

# The test harness does not run the hook, so invoke it here.
/usr/local/share/codex/init.sh

check "CODEX_HOME exported" bash -lc '[ "$CODEX_HOME" = /var/codex ]'
# The binary still resolves now that CODEX_HOME points away from the payload.
check "codex runs against the state dir" bash -lc "codex --version"

# The scenario mounts no volume, so the hook reports where the state dir really is.
check "the hook reports the unmounted state dir" \
  bash -c '/usr/local/share/codex/init.sh 2>&1 >/dev/null | grep -q "on the container filesystem"'

# Report result
reportResults
