#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Run as a non-root dev user, whose home keeps the state dir theirs across a UID remap.
check "state dir pre-created" test -d /home/ubuntu/latex
check "state dir writable by the dev user" bash -c 'touch /home/ubuntu/latex/.probe && rm /home/ubuntu/latex/.probe'

# The hook installs all of TeX Live, so this scenario covers the parts around it.
check "PATH points into the state dir" grep -qF '/home/ubuntu/latex/texlive/' /etc/profile.d/latex.sh

# A path outside the home proves the guard rejects what it should.
check "a state dir outside the home is refused" \
  bash -c '! /usr/local/libexec/latex/state-dir.sh latex /var/latex'
check "the refusal names the home" \
  bash -c '/usr/local/libexec/latex/state-dir.sh latex /var/latex 2>&1 | grep -q "must be inside /home/ubuntu"'

# Report result
reportResults
