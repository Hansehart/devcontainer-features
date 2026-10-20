#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Run the hook as a container create does.
/usr/local/libexec/node/init.sh

target="${NPM_CONFIG_USERCONFIG:-$HOME/.npmrc}"
check "npmrc written" grep -qF 'audit-level=low' "$target"
check "escaped newlines expanded" bash -c "[ \"\$(wc -l < '$target')\" -eq 2 ]"
check "npm reads the config" bash -lc "npm config get audit-level | grep -qF 'low'"

# The hook owns the file, so a re-run restores the requested content.
printf 'audit-level=critical\n' > "$target"
/usr/local/libexec/node/init.sh
check "npmrc restored on re-run" grep -qF 'audit-level=low' "$target"

# Report result
reportResults
