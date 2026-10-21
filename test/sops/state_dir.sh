#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Run as a non-root dev user, whose home keeps the state dir theirs across a UID remap.
check "state dir pre-created" test -d /home/ubuntu/sops
check "state dir writable by the dev user" bash -c 'touch /home/ubuntu/sops/.probe && rm /home/ubuntu/sops/.probe'

# Run the hook as a container create does.
/usr/local/libexec/sops/init.sh

check "SOPS_AGE_KEY_FILE exported" bash -lc '[ "$SOPS_AGE_KEY_FILE" = /home/ubuntu/sops/keys.txt ]'

# This scenario keeps the state dir on the container filesystem, which the hook warns about.
check "the hook reports the unmounted state dir" \
  bash -c '/usr/local/libexec/sops/init.sh 2>&1 >/dev/null | grep -q "on the container filesystem"'

# A path outside the home proves the guard rejects what it should.
check "a state dir outside the home is refused" \
  bash -c '! /usr/local/libexec/sops/state-dir.sh sops /var/sops'
check "the refusal names the home" \
  bash -c '/usr/local/libexec/sops/state-dir.sh sops /var/sops 2>&1 | grep -q "must be inside /home/ubuntu"'

# Report result
reportResults
