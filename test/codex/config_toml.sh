#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Run the hook as a container create does.
/usr/local/libexec/codex/init.sh

target="${CODEX_HOME:-$HOME/.codex}/config.toml"
check "config written" grep -qF 'approval_policy = "untrusted"' "$target"
check "escaped newlines expanded" bash -c "[ \"\$(wc -l < '$target')\" -eq 2 ]"

# The hook owns the file, so a re-run restores the requested content.
printf 'approval_policy = "never"\n' > "$target"
/usr/local/libexec/codex/init.sh
check "config restored on re-run" grep -qF 'approval_policy = "untrusted"' "$target"

# Report result
reportResults
