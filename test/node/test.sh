#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Use a login shell so the profile.d snippet setting the npm prefix is sourced.
check "node on PATH" bash -lc "command -v node"
check "node version" bash -lc "node --version"
check "npm on PATH" bash -lc "command -v npm"
check "npx on PATH" bash -lc "command -v npx"
check "global prefix in the dev user's home" bash -lc '[ "$(npm prefix -g)" = "$HOME/.local" ]'
check "global prefix writable by the dev user" bash -lc 'mkdir -p "$(npm prefix -g)/lib" && touch "$(npm prefix -g)/lib/.probe" && rm "$(npm prefix -g)/lib/.probe"'

# Report result
reportResults
