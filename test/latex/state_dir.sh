#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Runs as a non-root remoteUser, which the CLI may remap to a different UID at build time.
check "state dir pre-created" test -d /var/latex
check "dev user in the state dir group" bash -c 'id -nG | grep -qw latex'
check "state dir writable by the dev user" bash -c 'touch /var/latex/.probe && rm /var/latex/.probe'

# Unlike the other features the hook is not invoked here because it installs all of TeX Live.
check "PATH points into the state dir" grep -qF '/var/latex/texlive/' /etc/profile.d/latex.sh

# Report result
reportResults
