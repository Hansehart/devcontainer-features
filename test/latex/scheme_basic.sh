#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

# scheme-basic ships latex/pdflatex (not latexmk/biber), so assert just those.
# The install mechanism is scheme-independent, so this validates the full path.
check "latex" latex --version
check "pdflatex" pdflatex --version

# Report result
reportResults
