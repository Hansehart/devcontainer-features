#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# The test harness does not run the hook, so invoke it here to apply the baked config.
/usr/local/share/codex/init.sh

target="${CODEX_HOME:-$HOME/.codex}/config.toml"
check "config written" grep -qF 'approval_policy = "untrusted"' "$target"
check "escaped newlines expanded" bash -c "[ \"\$(wc -l < '$target')\" -eq 2 ]"

# The hook owns config.toml, so a re-run restores the requested config.
printf 'approval_policy = "never"\n' > "$target"
/usr/local/share/codex/init.sh
check "config restored on re-run" grep -qF 'approval_policy = "untrusted"' "$target"

# Report result
reportResults
