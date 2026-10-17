#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Run as a non-root dev user, whose home keeps the state dir theirs across a UID remap.
check "state dir pre-created" test -d /home/ubuntu/claude-code
check "state dir writable by the dev user" bash -c 'touch /home/ubuntu/claude-code/.probe && rm /home/ubuntu/claude-code/.probe'

# Run the hook as a container create does.
/usr/local/share/claude-code/init.sh

check "CLAUDE_CONFIG_DIR exported" bash -lc '[ "$CLAUDE_CONFIG_DIR" = /home/ubuntu/claude-code ]'

# The hook keeps its output private to the dev user.
check "settings written by the hook" test -f /home/ubuntu/claude-code/settings.json
check "hook output private to the dev user" \
  bash -c '[ -z "$(find /home/ubuntu/claude-code/settings.json -maxdepth 0 -perm /g+rwx,o+rwx)" ]'

# This scenario keeps the state dir on the container filesystem, which the hook warns about.
check "the hook reports the unmounted state dir" \
  bash -c '/usr/local/share/claude-code/init.sh 2>&1 >/dev/null | grep -q "on the container filesystem"'

# A path outside the home proves the guard rejects what it should.
check "a state dir outside the home is refused" \
  bash -c '! /usr/local/share/claude-code/state-dir.sh claude-code /var/claude-code'
check "the refusal names the home" \
  bash -c '/usr/local/share/claude-code/state-dir.sh claude-code /var/claude-code 2>&1 | grep -q "must be inside /home/ubuntu"'

# Report result
reportResults
