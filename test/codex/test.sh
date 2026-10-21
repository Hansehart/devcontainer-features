#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Use a login shell, which reads the feature's profile.
check "codex on PATH" bash -lc "command -v codex"
check "codex version" bash -lc "codex --version"

# The tool's searches rely on ripgrep.
check "ripgrep on PATH" bash -lc "command -v rg"

# Keep the binary apart from the state dir, so a volume there leaves it in view.
check "payload outside the state dir" bash -lc 'case "$(readlink -f "$(command -v codex)")" in "$HOME"/.local/share/codex/*) ;; *) exit 1;; esac'
check "state dir holds no payload" bash -lc 'test ! -e "$HOME/.codex/packages"'
# The requested config sits with the feature's config.
check "requested config in the feature's config dir" test -f /usr/local/etc/codex/requested-config.toml

# Report result
reportResults
