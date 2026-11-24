#!/usr/bin/env python3
"""racer_results の前後スナップショット（10_snapshot_racer_results.sql の出力 TSV）を比較する。

使い方: python3 -I compare_snapshots.py before.tsv after.tsv

判定:
  - 是正対象8件（2026-27 の6件＋2023-24 の2件）: 変わってよい列は as_category と modified のみ。as_category は UCIWJ→WJ であること。（要件1.3, 2.4）
  - それ以外の行: 一切変わっていないこと（追加・削除・値の変化なし）。（要件2.5）
    本番では他の運営者の取込で変わる行がありうるため、差分があれば一覧を出して人間が判断する。
終了コード: 0 = 期待どおり / 1 = 差分あり
"""
import csv
import sys

TARGET_IDS = {"359429", "359430", "360444", "360445", "360446", "360447",  # 2026-27 の6件
              "277933", "277934"}  # 2023-24 の2件（表示揃え）
ALLOWED_TARGET_COLS = {"as_category", "modified"}

csv.field_size_limit(sys.maxsize)


def load(path):
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.reader(f, delimiter="\t", quoting=csv.QUOTE_NONE)
        header = next(reader)
        rows = {}
        for r in reader:
            rows[r[0]] = dict(zip(header, r))
        return header, rows


def main(before_path, after_path):
    hb, before = load(before_path)
    ha, after = load(after_path)
    ok = True
    if hb != ha:
        print("NG: 列構成が違う", hb, ha)
        return 1

    print(f"rows before={len(before)} after={len(after)}")

    # 是正対象6件
    for rid in sorted(TARGET_IDS):
        b, a = before.get(rid), after.get(rid)
        if b is None or a is None:
            print(f"NG target {rid}: 行が無い before={b is not None} after={a is not None}")
            ok = False
            continue
        changed = [c for c in hb if b[c] != a[c]]
        bad = [c for c in changed if c not in ALLOWED_TARGET_COLS]
        # 是正そのものが効いたこと（UCIWJ → WJ）も明示的に確認する
        if not (b["as_category"] == "UCIWJ" and a["as_category"] == "WJ"):
            bad.append("as_category(expected UCIWJ->WJ)")
        status = "OK" if not bad else "NG"
        if bad:
            ok = False
        print(f"{status} target {rid}: changed={changed} as_category {b['as_category']} -> {a['as_category']}"
              f" ajocc_pt {b['ajocc_pt']} -> {a['ajocc_pt']}")

    # それ以外
    others_b = {k: v for k, v in before.items() if k not in TARGET_IDS}
    others_a = {k: v for k, v in after.items() if k not in TARGET_IDS}
    added = sorted(set(others_a) - set(others_b), key=int)
    removed = sorted(set(others_b) - set(others_a), key=int)
    modified = [k for k in others_b.keys() & others_a.keys() if others_b[k] != others_a[k]]
    print(f"others: added={len(added)} removed={len(removed)} modified={len(modified)}")
    for k in added[:50]:
        print("  added   ", k, others_a[k].get("modified"))
    for k in removed[:50]:
        print("  removed ", k)
    for k in sorted(modified, key=int)[:50]:
        cols = [c for c in hb if others_b[k][c] != others_a[k][c]]
        print("  modified", k, cols, others_a[k].get("modified"))
    if added or removed or modified:
        ok = False

    print("COMPARE:", "OK" if ok else "NG")
    return 0 if ok else 1


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2]))
