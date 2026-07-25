#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Use a login shell so the profile.d snippet adding ~/.local/bin to PATH is sourced.
check "uv on PATH" bash -lc "command -v uv"
check "uv version" bash -lc "uv --version"
check "uvx on PATH" bash -lc "command -v uvx"

# Report result
reportResults
