#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Runs as a non-root remoteUser, which the CLI may remap to a different UID at build time.
check "state dir pre-created" test -d /var/uv
check "dev user in the state dir group" bash -c 'id -nG | grep -qw uv'
check "state dir writable by the dev user" bash -c 'touch /var/uv/.probe && rm /var/uv/.probe'

# The test harness does not run the hook, so invoke it here.
/usr/local/share/uv/init.sh

check "UV_CACHE_DIR exported" bash -lc '[ "$UV_CACHE_DIR" = /var/uv/cache ]'

# Report result
reportResults
