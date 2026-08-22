#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Use a login shell so the profile.d snippet adding ~/.local/bin to PATH is sourced.
check "codex on PATH" bash -lc "command -v codex"
check "codex version" bash -lc "codex --version"

# The payload must sit outside CODEX_HOME so a volume on the state dir cannot shadow the binary.
check "payload outside the state dir" bash -lc 'case "$(readlink -f "$(command -v codex)")" in "$HOME"/.local/share/codex/*) ;; *) exit 1;; esac'
check "state dir holds no payload" bash -lc 'test ! -e "$HOME/.codex/packages"'

# Report result
reportResults
