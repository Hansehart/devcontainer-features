#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Runs as root, the dev user a scenario gets when it omits remoteUser. The state dir grants
# below are shared by every state dir feature, so this covers that path for all of them.
check "state dir pre-created" test -d /var/tea
check "root in the state dir group" bash -c 'id -nG | grep -qw tea'
check "state dir writable by root" bash -c 'touch /var/tea/.probe && rm /var/tea/.probe'

# Covers the build-time link where su - targets root.
check "config dir is a link to the state dir" \
  bash -c '[ -L "$HOME/.config/tea" ] && [ "$(readlink "$HOME/.config/tea")" = /var/tea ]'

# Run the hook here, as a create does.
/usr/local/share/tea/init.sh

check "config dir linked at the state dir" \
  bash -c '[ "$(readlink -f "$HOME/.config/tea")" = /var/tea ]'

# Report result
reportResults
