#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Run as a non-root dev user, whose home keeps the state dir theirs across a UID remap.
check "state dir pre-created" test -d /home/ubuntu/codex
check "state dir writable by the dev user" bash -c 'touch /home/ubuntu/codex/.probe && rm /home/ubuntu/codex/.probe'

# Run the hook as a container create does.
/usr/local/libexec/codex/init.sh

check "CODEX_HOME exported" bash -lc '[ "$CODEX_HOME" = /home/ubuntu/codex ]'

# The hook keeps its output private to the dev user.
check "config written by the hook" test -f /home/ubuntu/codex/config.toml
check "hook output private to the dev user" \
  bash -c '[ -z "$(find /home/ubuntu/codex/config.toml -maxdepth 0 -perm /g+rwx,o+rwx)" ]'
# The binary keeps running with the state dir moved.
check "codex runs against the state dir" bash -lc "codex --version"

# This scenario keeps the state dir on the container filesystem, which the hook warns about.
check "the hook reports the unmounted state dir" \
  bash -c '/usr/local/libexec/codex/init.sh 2>&1 >/dev/null | grep -q "on the container filesystem"'

# A path outside the home proves the guard rejects what it should.
check "a state dir outside the home is refused" \
  bash -c '! /usr/local/libexec/codex/state-dir.sh codex /var/codex'
check "the refusal names the home" \
  bash -c '/usr/local/libexec/codex/state-dir.sh codex /var/codex 2>&1 | grep -q "must be inside /home/ubuntu"'

# Report result
reportResults
