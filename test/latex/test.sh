#!/bin/bash
set -e

# Import the test library
source dev-container-features-test-lib

check "latex on PATH" bash -c "command -v latex"
check "latex version" latex --version
check "pdflatex on PATH" bash -c "command -v pdflatex"

# TeX Live lives in its own tree, with its generated data in the variable data dir.
check "latex links into the TeX Live tree" bash -c "readlink -f \"\$(command -v latex)\" | grep -q '^/opt/texlive/'"
check "generated data in /var/opt" bash -c "kpsewhich -var-value TEXMFSYSVAR | grep -q '^/var/opt/texlive/'"
# Compile a document, which reads the formats from the generated data.
doc="$(mktemp -d)"
printf '\\documentclass{article}\\begin{document}Hello\\end{document}\n' > "$doc/hello.tex"
check "pdflatex compiles a document" bash -c "cd '$doc' && pdflatex -interaction=nonstopmode hello.tex >/dev/null && test -s hello.pdf"

# Report result
reportResults
