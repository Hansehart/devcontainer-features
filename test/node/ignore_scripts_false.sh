#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# A project whose postinstall leaves a marker shows whether npm runs install scripts.
project="$(mktemp -d)"
cat > "$project/package.json" <<'EOF'
{
  "name": "probe",
  "version": "1.0.0",
  "scripts": { "postinstall": "touch ran" }
}
EOF

check "npm keeps its own default" bash -lc '[ -z "${NPM_CONFIG_IGNORE_SCRIPTS:-}" ]'
check "npm install runs the postinstall" bash -lc "cd '$project' && npm install --offline --no-audit --no-fund >/dev/null && [ -e ran ]"

# Report result
reportResults
