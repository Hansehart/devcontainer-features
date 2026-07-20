#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# Assert the core binaries this scheme provides.
check "latex" latex --version
check "pdflatex" pdflatex --version

# Report result
reportResults
