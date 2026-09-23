#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Runs as a non-root remoteUser the CLI may remap at build time. The state dir sits in
# that user's home, the one place the remap chowns, so it stays theirs without a group.
check "state dir pre-created" test -d /home/ubuntu/latex
check "state dir writable by the dev user" bash -c 'touch /home/ubuntu/latex/.probe && rm /home/ubuntu/latex/.probe'

# Unlike the other features the hook is not invoked here because it installs all of TeX Live.
check "PATH points into the state dir" grep -qF '/home/ubuntu/latex/texlive/' /etc/profile.d/latex.sh

# An in-home path is accepted whether the guard works or lets every path through, so a
# path outside the home is what shows it is doing its job.
check "a state dir outside the home is refused" \
  bash -c '! /usr/local/share/latex/state-dir.sh latex /var/latex'
check "the refusal names the home" \
  bash -c '/usr/local/share/latex/state-dir.sh latex /var/latex 2>&1 | grep -q "must be inside /home/ubuntu"'

# Report result
reportResults
