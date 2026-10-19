#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Use a login shell, which reads the feature's profile.
check "node on PATH" bash -lc "command -v node"
check "node version" bash -lc "node --version"
# The default channel floats, so assert its mark: LTS majors are even.
check "default resolved an LTS line" bash -lc "node --version | grep -qE '^v[0-9]*[02468]\.'"
check "npm on PATH" bash -lc "command -v npm"
check "npx on PATH" bash -lc "command -v npx"
check "global prefix in the dev user's home" bash -lc '[ "$(npm prefix -g)" = "$HOME/.local" ]'
check "global prefix writable by the dev user" bash -lc 'mkdir -p "$(npm prefix -g)/lib" && touch "$(npm prefix -g)/lib/.probe" && rm "$(npm prefix -g)/lib/.probe"'

# The runtime lives in its own folder, linked onto the PATH.
for cmd in node npm npx; do
  check "$cmd links into the node folder" bash -c "readlink -f \"\$(command -v $cmd)\" | grep -q '^/opt/node/'"
done
check "nothing left in the shared tree" test ! -e /usr/local/lib/node_modules/npm
# Drop the profile's prefix, so the global prefix comes from the feature's global config.
check "global prefix stays on the default PATH" bash -c '[ "$(env -u NPM_CONFIG_PREFIX npm prefix -g)" = /usr/local ]'

# A project whose postinstall leaves a marker shows whether npm runs install scripts.
project="$(mktemp -d)"
cat > "$project/package.json" <<'EOF'
{
  "name": "probe",
  "version": "1.0.0",
  "scripts": { "postinstall": "touch ran" }
}
EOF

check "install scripts ignored by default" bash -lc '[ "$NPM_CONFIG_IGNORE_SCRIPTS" = true ]'
check "npm install skips the postinstall" bash -lc "cd '$project' && npm install --offline --no-audit --no-fund >/dev/null && [ ! -e ran ]"
check "npm run still runs the script by name" bash -lc "cd '$project' && npm run --silent postinstall && [ -e ran ]"

# Report result
reportResults
