#!/bin/bash
set -e
DIR="/Users/kyamady/workspace/cyclox2_docker/.claude/worktrees/interesting-bouman-d5368b/.kiro/specs/ajocc-report-2025-26"
OUT="$DIR/outputs"
cd "$DIR"
node build_report.js
/opt/homebrew/bin/soffice --headless --convert-to pdf --outdir "$OUT" "$OUT/25-26_AJOCC_report.pptx" >/dev/null 2>&1
rm -f "$OUT"/qa-*.png
/opt/homebrew/bin/pdftoppm -png -r 120 "$OUT/25-26_AJOCC_report.pdf" "$OUT/qa"
ls "$OUT"/qa-*.png | sort
