#!/bin/bash
set -e

# Optional: Import test library
source dev-container-features-test-lib

# claude installs into the remote user's ~/.local/bin; use a login shell so the
# profile.d snippet this Feature writes is sourced.
check "claude on PATH" bash -lc "command -v claude"
check "claude version" bash -lc "claude --version"

# Report result
reportResults
