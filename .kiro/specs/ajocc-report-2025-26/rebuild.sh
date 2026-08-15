#!/bin/bash
set -e
# DIRはこのスクリプト自身の場所から解決する（特定のgit worktree/checkoutパスに依存しない）。
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$DIR/outputs"
mkdir -p "$OUT"
cd "$DIR"
node build_report.js
/opt/homebrew/bin/soffice --headless --convert-to pdf --outdir "$OUT" "$OUT/25-26_AJOCC_report.pptx" >/dev/null 2>&1
rm -f "$OUT"/qa-*.png
/opt/homebrew/bin/pdftoppm -png -r 120 "$OUT/25-26_AJOCC_report.pdf" "$OUT/qa"
ls "$OUT"/qa-*.png | sort
