#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Runs as a non-root remoteUser, which the CLI may remap to a different UID at build time.
check "state dir pre-created" test -d /var/node
check "dev user in the state dir group" bash -c 'id -nG | grep -qw node'
check "state dir writable by the dev user" bash -c 'touch /var/node/.probe && rm /var/node/.probe'

# The test harness does not run the hook, so invoke it here.
/usr/local/share/node/init.sh

check "NPM_CONFIG_CACHE exported" bash -lc '[ "$NPM_CONFIG_CACHE" = /var/node/cache ]'
check "NPM_CONFIG_USERCONFIG exported" bash -lc '[ "$NPM_CONFIG_USERCONFIG" = /var/node/npmrc ]'
check "global prefix in the state dir" bash -lc '[ "$(npm prefix -g)" = /var/node/global ]'
check "global prefix created" test -d /var/node/global

# Report result
reportResults
