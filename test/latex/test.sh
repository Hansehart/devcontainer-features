#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "latex on PATH" bash -c "command -v latex"
check "latex version" latex --version
check "pdflatex on PATH" bash -c "command -v pdflatex"

# Report result
reportResults
