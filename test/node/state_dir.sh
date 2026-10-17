#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Run as a non-root dev user, whose home keeps the state dir theirs across a UID remap.
check "state dir pre-created" test -d /home/ubuntu/node
check "state dir writable by the dev user" bash -c 'touch /home/ubuntu/node/.probe && rm /home/ubuntu/node/.probe'

# Run the hook as a container create does.
/usr/local/share/node/init.sh

check "NPM_CONFIG_CACHE exported" bash -lc '[ "$NPM_CONFIG_CACHE" = /home/ubuntu/node/cache ]'
check "NPM_CONFIG_USERCONFIG exported" bash -lc '[ "$NPM_CONFIG_USERCONFIG" = /home/ubuntu/node/npmrc ]'
check "global prefix in the state dir" bash -lc '[ "$(npm prefix -g)" = /home/ubuntu/node/global ]'
check "global prefix created" test -d /home/ubuntu/node/global

# The hook keeps its output private to the dev user.
check "hook output private to the dev user" \
  bash -c '[ -z "$(find /home/ubuntu/node/cache /home/ubuntu/node/global -maxdepth 0 -perm /g+rwx,o+rwx)" ]'

# This scenario keeps the state dir on the container filesystem, which the hook warns about.
check "the hook reports the unmounted state dir" \
  bash -c '/usr/local/share/node/init.sh 2>&1 >/dev/null | grep -q "on the container filesystem"'

# A path outside the home proves the guard rejects what it should.
check "a state dir outside the home is refused" \
  bash -c '! /usr/local/share/node/state-dir.sh node /var/node'
check "the refusal names the home" \
  bash -c '/usr/local/share/node/state-dir.sh node /var/node 2>&1 | grep -q "must be inside /home/ubuntu"'

# Report result
reportResults
