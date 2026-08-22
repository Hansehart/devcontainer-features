#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Checks run as a non-root remoteUser because root would pass them regardless of ownership.
check "state dir pre-created" test -d /var/uv
check "state dir owned by the dev user" bash -c '[ "$(stat -c %U /var/uv)" = "$(id -un)" ]'
check "state dir writable by the dev user" bash -c 'touch /var/uv/.probe && rm /var/uv/.probe'

# The test harness does not run the hook, so invoke it here.
/usr/local/share/uv/init.sh

check "UV_CACHE_DIR exported" bash -lc '[ "$UV_CACHE_DIR" = /var/uv/cache ]'

# Report result
reportResults
