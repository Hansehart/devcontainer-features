#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Checks run as a non-root remoteUser because root would pass them regardless of ownership.
check "state dir pre-created" test -d /var/latex
check "state dir owned by the dev user" bash -c '[ "$(stat -c %U /var/latex)" = "$(id -un)" ]'
check "state dir writable by the dev user" bash -c 'touch /var/latex/.probe && rm /var/latex/.probe'

# Unlike the other features the hook is not invoked here because it installs all of TeX Live.
check "PATH points into the state dir" grep -qF '/var/latex/texlive/' /etc/profile.d/latex.sh

# Report result
reportResults
