#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Use a login shell so the profile.d snippet setting the npm prefix is sourced.
check "node on PATH" bash -lc "command -v node"
check "node version" bash -lc "node --version"
# The default channel floats, so assert what identifies it: LTS majors are always even.
check "default resolved an LTS line" bash -lc "node --version | grep -qE '^v[0-9]*[02468]\.'"
check "npm on PATH" bash -lc "command -v npm"
check "npx on PATH" bash -lc "command -v npx"
check "global prefix in the dev user's home" bash -lc '[ "$(npm prefix -g)" = "$HOME/.local" ]'
check "global prefix writable by the dev user" bash -lc 'mkdir -p "$(npm prefix -g)/lib" && touch "$(npm prefix -g)/lib/.probe" && rm "$(npm prefix -g)/lib/.probe"'

# A project whose postinstall leaves a marker shows whether npm runs install scripts.
probe='d="$(mktemp -d)" && cd "$d" && printf "%s" "{\"name\":\"probe\",\"version\":\"1.0.0\",\"scripts\":{\"postinstall\":\"touch ran\"}}" > package.json && npm install --offline --no-audit --no-fund >/dev/null'
check "install scripts ignored by default" bash -lc '[ "$NPM_CONFIG_IGNORE_SCRIPTS" = true ]'
check "npm install skips the postinstall" bash -lc "$probe && [ ! -e ran ]"
check "npm run still runs the script by name" bash -lc "$probe && npm run --silent postinstall && [ -e ran ]"

# Report result
reportResults
