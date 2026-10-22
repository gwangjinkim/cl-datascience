#!/bin/sh
# Build docs/NAME.pdf from docs/NAME.md (needs pandoc and xelatex).
#   docs/build-pdf.sh                 # DESIGN
#   docs/build-pdf.sh INTRODUCTION
cd "$(dirname "$0")" || exit 1
name="${1:-DESIGN}"
pandoc "$name.md" -o "$name.pdf" --pdf-engine=xelatex --toc --toc-depth=2 -N \
  -V geometry:margin=2.2cm -V papersize=a4 -V fontsize=11pt \
  -V mainfont="Palatino" -V colorlinks=true -V linkcolor=black -V urlcolor=blue \
  -H pdf-header.tex
