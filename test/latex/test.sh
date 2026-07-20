#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "latex" latex --version
check "pdflatex" pdflatex --version

# Report result
reportResults
