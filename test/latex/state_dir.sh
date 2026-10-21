#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Run as a non-root dev user, whose home keeps the state dir theirs across a UID remap.
check "state dir pre-created" test -d /home/ubuntu/latex
check "state dir writable by the dev user" bash -c 'touch /home/ubuntu/latex/.probe && rm /home/ubuntu/latex/.probe'

# TeX Live sits in the image, and the state dir holds the user's own TeX data.
check "latex links into the TeX Live tree" bash -c "readlink -f \"\$(command -v latex)\" | grep -q '^/opt/texlive/'"

# Run the hook as a container create does.
/usr/local/libexec/latex/init.sh

check "TEXMFHOME exported" bash -lc '[ "$TEXMFHOME" = /home/ubuntu/latex/texmf ]'
check "TEXMFVAR exported" bash -lc '[ "$TEXMFVAR" = /home/ubuntu/latex/texmf-var ]'
check "TEXMFCONFIG exported" bash -lc '[ "$TEXMFCONFIG" = /home/ubuntu/latex/texmf-config ]'
check "the hook creates the user trees" \
  test -d /home/ubuntu/latex/texmf -a -d /home/ubuntu/latex/texmf-var -a -d /home/ubuntu/latex/texmf-config

# A package in the user tree is found, the way one installed with tlmgr --usermode would be.
mkdir -p /home/ubuntu/latex/texmf/tex/latex/probe
touch /home/ubuntu/latex/texmf/tex/latex/probe/probe.sty
check "TeX finds a package in the state dir" \
  bash -lc 'kpsewhich probe.sty | grep -qx /home/ubuntu/latex/texmf/tex/latex/probe/probe.sty'

# This scenario keeps the state dir on the container filesystem, which the hook warns about.
check "the hook reports the unmounted state dir" \
  bash -c '/usr/local/libexec/latex/init.sh 2>&1 >/dev/null | grep -q "on the container filesystem"'

# A path outside the home proves the guard rejects what it should.
check "a state dir outside the home is refused" \
  bash -c '! /usr/local/libexec/latex/state-dir.sh latex /var/latex'
check "the refusal names the home" \
  bash -c '/usr/local/libexec/latex/state-dir.sh latex /var/latex 2>&1 | grep -q "must be inside /home/ubuntu"'

# Report result
reportResults
