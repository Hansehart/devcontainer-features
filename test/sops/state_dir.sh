#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Runs as a non-root remoteUser the CLI may remap at build time. The state dir sits in
# that user's home, the one place the remap chowns, so it stays theirs without a group.
check "state dir pre-created" test -d /home/ubuntu/sops
check "state dir writable by the dev user" bash -c 'touch /home/ubuntu/sops/.probe && rm /home/ubuntu/sops/.probe'

# The test harness does not run the hook, so invoke it here.
/usr/local/share/sops/init.sh

check "SOPS_AGE_KEY_FILE exported" bash -lc '[ "$SOPS_AGE_KEY_FILE" = /home/ubuntu/sops/keys.txt ]'

# The scenario mounts no volume, so the hook reports where the state dir really is.
check "the hook reports the unmounted state dir" \
  bash -c '/usr/local/share/sops/init.sh 2>&1 >/dev/null | grep -q "on the container filesystem"'

# An in-home path is accepted whether the guard works or lets every path through, so a
# path outside the home is what shows it is doing its job.
check "a state dir outside the home is refused" \
  bash -c '! /usr/local/share/sops/state-dir.sh sops /var/sops'
check "the refusal names the home" \
  bash -c '/usr/local/share/sops/state-dir.sh sops /var/sops 2>&1 | grep -q "must be inside /home/ubuntu"'

# Report result
reportResults
