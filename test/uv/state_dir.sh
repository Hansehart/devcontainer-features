#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Runs as a non-root remoteUser the CLI may remap at build time. The state dir sits in
# that user's home, the one place the remap chowns, so it stays theirs without a group.
check "state dir pre-created" test -d /home/ubuntu/uv
check "state dir writable by the dev user" bash -c 'touch /home/ubuntu/uv/.probe && rm /home/ubuntu/uv/.probe'

# The test harness does not run the hook, so invoke it here.
/usr/local/share/uv/init.sh

check "UV_CACHE_DIR exported" bash -lc '[ "$UV_CACHE_DIR" = /home/ubuntu/uv/cache ]'

# The scenario mounts no volume, so the hook reports where the state dir really is.
check "the hook reports the unmounted state dir" \
  bash -c '/usr/local/share/uv/init.sh 2>&1 >/dev/null | grep -q "on the container filesystem"'

# An in-home path is accepted whether the guard works or lets every path through, so a
# path outside the home is what shows it is doing its job.
check "a state dir outside the home is refused" \
  bash -c '! /usr/local/share/uv/state-dir.sh uv /var/uv'
check "the refusal names the home" \
  bash -c '/usr/local/share/uv/state-dir.sh uv /var/uv 2>&1 | grep -q "must be inside /home/ubuntu"'

# Report result
reportResults
