#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
2025-26シーズンの集計行を参照ファイルの「通しでカウント」シートに追加して新規Excelを生成する。

- 入力: tmp/20250416_entry_racers.xlsx（参照ファイル。書式・他シートは温存）
- 出力: tmp/20260621_entry_racers.xlsx
- 追加行: 25-26 / entry / started / 前年比entry / 前年比started

集計値は docs/specs/entry-count-2025-26/test-results.md の検算結果に基づく定数。
（再計算が必要な場合は同ドキュメントの Runbook の SQL を実行して値を更新すること）
"""
from copy import copy
import os
import openpyxl

# tmp/ は .gitignore 対象でメインチェックアウト側にのみ存在する。
# worktree 実行時もメインリポジトリの tmp/ を指すよう CYCLOX_REPO で上書き可能にする。
REPO = os.environ.get("CYCLOX_REPO", "/Users/kyamady/workspace/cyclox2_docker")
SRC = os.path.join(REPO, "tmp", "20250416_entry_racers.xlsx")
DST = os.path.join(REPO, "tmp", "20260621_entry_racers.xlsx")

# --- 集計結果（test-results.md より） ---
SEASON = "25-26"
ENTRY = 21604
STARTED = 18802
PREV_ENTRY = 21644      # 24-25 entry
PREV_STARTED = 19094    # 24-25 started
DIFF_ENTRY = ENTRY - PREV_ENTRY        # -40
DIFF_STARTED = STARTED - PREV_STARTED  # -292


def main():
    wb = openpyxl.load_workbook(SRC)  # data_only=False: 書式・数式を温存
    ws = wb["通しでカウント"]

    # 既存の最終データ行（24-25）を探す: B列がシーズン文字列の最終行
    last_row = None
    for r in range(ws.max_row, 1, -1):
        v = ws.cell(row=r, column=2).value  # B列
        if isinstance(v, str) and "-" in v:
            last_row = r
            break
    if last_row is None:
        raise RuntimeError("既存のシーズン行が見つかりません")

    prev = ws.cell(row=last_row, column=2).value
    print(f"既存最終行: row={last_row} (season={prev})")
    if prev != "24-25":
        print(f"  注意: 想定の 24-25 ではなく {prev} でした。前年比の基準を確認すること。")

    new_row = last_row + 1
    # 前年比(E,F)は既存行と同じく数式で持たせる（=今年-前年）。entry/started は他行と同じく数値。
    values = {
        2: SEASON,
        3: ENTRY,
        4: STARTED,
        5: f"=C{new_row}-C{last_row}",
        6: f"=D{new_row}-D{last_row}",
    }
    for col in range(2, 7):
        src = ws.cell(row=last_row, column=col)
        dst = ws.cell(row=new_row, column=col)
        dst.value = values[col]
        # 24-25 行の書式を複製
        if src.has_style:
            dst.font = copy(src.font)
            dst.border = copy(src.border)
            dst.fill = copy(src.fill)
            dst.number_format = copy(src.number_format)
            dst.protection = copy(src.protection)
            dst.alignment = copy(src.alignment)

    # 他シートに多数の数式があるため、Excel起動時に全再計算させてキャッシュ欠落を防ぐ
    wb.calculation.fullCalcOnLoad = True

    wb.save(DST)
    print(f"出力: {DST}")
    print(f"追加行: row={new_row}  {SEASON} / entry={ENTRY} / started={STARTED} / "
          f"前年比entry={DIFF_ENTRY} / 前年比started={DIFF_STARTED}")


if __name__ == "__main__":
    main()
