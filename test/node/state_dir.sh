#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Runs as a non-root remoteUser the CLI may remap at build time. The state dir sits in
# that user's home, the one place the remap chowns, so it stays theirs without a group.
check "state dir pre-created" test -d /home/ubuntu/node
check "state dir writable by the dev user" bash -c 'touch /home/ubuntu/node/.probe && rm /home/ubuntu/node/.probe'

# The test harness does not run the hook, so invoke it here.
/usr/local/share/node/init.sh

check "NPM_CONFIG_CACHE exported" bash -lc '[ "$NPM_CONFIG_CACHE" = /home/ubuntu/node/cache ]'
check "NPM_CONFIG_USERCONFIG exported" bash -lc '[ "$NPM_CONFIG_USERCONFIG" = /home/ubuntu/node/npmrc ]'
check "global prefix in the state dir" bash -lc '[ "$(npm prefix -g)" = /home/ubuntu/node/global ]'
check "global prefix created" test -d /home/ubuntu/node/global

# The hook sets its own umask, so its output stays private to the dev user.
check "hook output private to the dev user" \
  bash -c '[ -z "$(find /home/ubuntu/node/cache /home/ubuntu/node/global -maxdepth 0 -perm /g+rwx,o+rwx)" ]'

# The scenario mounts no volume, so the hook reports where the state dir really is.
check "the hook reports the unmounted state dir" \
  bash -c '/usr/local/share/node/init.sh 2>&1 >/dev/null | grep -q "on the container filesystem"'

# An in-home path is accepted whether the guard works or lets every path through, so a
# path outside the home is what shows it is doing its job.
check "a state dir outside the home is refused" \
  bash -c '! /usr/local/share/node/state-dir.sh node /var/node'
check "the refusal names the home" \
  bash -c '/usr/local/share/node/state-dir.sh node /var/node 2>&1 | grep -q "must be inside /home/ubuntu"'

# Report result
reportResults
