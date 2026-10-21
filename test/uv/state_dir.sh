#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Run as a non-root dev user, whose home keeps the state dir theirs across a UID remap.
check "state dir pre-created" test -d /home/ubuntu/uv
check "state dir writable by the dev user" bash -c 'touch /home/ubuntu/uv/.probe && rm /home/ubuntu/uv/.probe'

# Run the hook as a container create does.
/usr/local/libexec/uv/init.sh

check "UV_CACHE_DIR exported" bash -lc '[ "$UV_CACHE_DIR" = /home/ubuntu/uv/cache ]'

# This scenario keeps the state dir on the container filesystem, which the hook warns about.
check "the hook reports the unmounted state dir" \
  bash -c '/usr/local/libexec/uv/init.sh 2>&1 >/dev/null | grep -q "on the container filesystem"'

# A path outside the home proves the guard rejects what it should.
check "a state dir outside the home is refused" \
  bash -c '! /usr/local/libexec/uv/state-dir.sh uv /var/uv'
check "the refusal names the home" \
  bash -c '/usr/local/libexec/uv/state-dir.sh uv /var/uv 2>&1 | grep -q "must be inside /home/ubuntu"'

# Report result
reportResults
