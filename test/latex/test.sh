#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "latex" latex --version
check "latexmk" latexmk --version
check "biber" biber --version

# Report result
reportResults
