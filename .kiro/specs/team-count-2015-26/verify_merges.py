#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
材料B（正規化で統合される生名称グループ）の全件検証。

目的: NFKC+casefold+空白除去 が「別チーム同士」を誤統合していないかを全1,952群で確認する。

原理:
  norm_key = NFKC(s) → 空白除去 → casefold。
  したがって1グループ内の生名称の差異は、この3操作が消した情報＝
    (a) 空白  (b) 大小文字  (c) NFKC互換変換（主に全半角・半角カナ）
  のいずれかに限定される（実文字が違えば同一キーにならない）。

検証分類（各グループを下記いずれかに割り当て）:
  [SPACE_CASE] 空白/大小文字のみで統合（NFKC不関与）→ 確実に同一チーム
  [WIDTH_KANA] 上記に加え「全半角ASCII / 半角カナ→全角カナ / 全角空白」だけのNFKC変換→ 同一チーム
  [EXOTIC]     上記に該当しない互換変換（①㈱Ⅳ㌔℡㎡ ﬀ 等）を含む → 要目視
  さらに [ACRONYM_RISK] 空白除去後が短く(<=4)、空白有無で語境界が変わりうる群 → 念のため列挙

EXOTIC と ACRONYM_RISK のみ人手確認すればよい（他は構造上安全）。
"""
import importlib.util
import os
import sys
import unicodedata
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("at", os.path.join(HERE, "analyze_teams.py"))
at = importlib.util.module_from_spec(spec)
spec.loader.exec_module(at)


def remove_spaces(s):
    return "".join(ch for ch in s if not ch.isspace() and ch != "　")


def lite_key(s):
    """NFKCを使わない簡易キー（空白除去＋casefold）。"""
    return remove_spaces(s).casefold()


def is_benign_fold_char(ch):
    """そのcharのNFKC変換が『全半角ASCII / 半角カナ / 全角空白』に由来する良性変換か。"""
    if unicodedata.normalize("NFKC", ch) == ch:
        return True  # そもそも変換されない
    o = ord(ch)
    if o == 0x3000:                       # 全角スペース
        return True
    if 0xFF01 <= o <= 0xFF5E:             # 全角ASCII（英数記号）→ 半角
        return True
    if 0xFF61 <= o <= 0xFF9F:             # 半角カナ・半角濁点等 → 全角カナ
        return True
    return False                          # それ以外の互換変換 = EXOTIC


def classify(raws):
    lites = {lite_key(r) for r in raws}
    if len(lites) == 1:
        return "SPACE_CASE", set()
    # NFKCが関与。exoticな文字を収集
    exotic = set()
    for r in raws:
        for ch in r:
            if not is_benign_fold_char(ch):
                exotic.add(ch)
    if exotic:
        return "EXOTIC", exotic
    return "WIDTH_KANA", set()


def main():
    rows = at.load_rows()
    key_to_raws = defaultdict(lambda: defaultdict(int))
    for year, cnt, raw in rows:
        if at.is_noteam(raw):
            continue
        key_to_raws[at.norm(raw)][raw.strip()] += cnt

    merged = {k: v for k, v in key_to_raws.items() if len(v) >= 2}

    buckets = defaultdict(list)
    acronym_risk = []
    for k, raws in merged.items():
        cls, exotic = classify(list(raws.keys()))
        buckets[cls].append((k, raws, exotic))
        # ACRONYM_RISK: 空白除去が効いており(=空白を含む生名がある)かつ短い
        has_space = any((" " in r or "　" in r or "\t" in r) for r in raws)
        if has_space and len(remove_spaces(max(raws, key=lambda x: raws[x]))) <= 4:
            acronym_risk.append((k, raws))

    total = len(merged)
    print(f"統合グループ総数: {total}")
    for b in ("SPACE_CASE", "WIDTH_KANA", "EXOTIC"):
        print(f"  [{b:10}] {len(buckets[b])}")
    print(f"  [ACRONYM_RISK] {len(acronym_risk)}（空白除去×短文字、念のため列挙）")
    print()
    print("=" * 70)
    print("【要目視 1】EXOTIC: 全半角/半角カナ以外の互換変換を含む群（誤統合の恐れ）")
    print("=" * 70)
    if not buckets["EXOTIC"]:
        print("  該当なし → NFKCの互換変換は全て全半角/半角カナのみ。誤統合リスクなし。")
    else:
        for k, raws, exotic in sorted(buckets["EXOTIC"], key=lambda x: -sum(x[1].values())):
            ex = " ".join(f"{c!r}->{unicodedata.normalize('NFKC', c)!r}" for c in exotic)
            items = " | ".join(f"{n!r}×{c}" for n, c in sorted(raws.items(), key=lambda x: -x[1]))
            print(f"  exotic[{ex}]\n    {items}")

    print()
    print("=" * 70)
    print("【要目視 2】ACRONYM_RISK: 空白除去で語境界が変わりうる短い群")
    print("=" * 70)
    if not acronym_risk:
        print("  該当なし")
    else:
        for k, raws in sorted(acronym_risk, key=lambda x: -sum(x[1].values())):
            items = " | ".join(f"{n!r}×{c}" for n, c in sorted(raws.items(), key=lambda x: -x[1]))
            print(f"  {items}")

    # WIDTH_KANA を全件出力（確認可能な形で）
    print()
    print("=" * 70)
    print("【参考】WIDTH_KANA 全件（全半角/半角カナのゆれのみ＝同一チーム）")
    print("=" * 70)
    for k, raws, _ in sorted(buckets["WIDTH_KANA"], key=lambda x: -sum(x[1].values())):
        items = " | ".join(f"{n!r}×{c}" for n, c in sorted(raws.items(), key=lambda x: -x[1]))
        print(f"  {items}")


if __name__ == "__main__":
    main()
