#!/usr/bin/env python3
"""header.php / footer.php のパートナーバナー <li> が www 由来スナップショットと一致するか検証する。
使い方: python3 check_banners.py <cyclox2res_sys のパス>
スナップショットは www.cyclocross.jp ヘッダー(#ptnr_logo_list01)抽出分。
差分はアクトサイクの画像パスのみ絶対URL化済み。比較は &amp; 正規化・空白除去後。"""
import re, sys, pathlib, urllib.parse

here = pathlib.Path(__file__).parent
root = pathlib.Path(sys.argv[1])
norm = lambda s: re.sub(r'\s+$', '', s.replace('&amp;', '&').strip())
expected = [norm(l) for l in (here / 'www-header-snapshot.html').read_text(encoding='utf-8').splitlines() if l.strip()]

ok = True
for rel, marker in [('application/views/templates/header.php', 'id="ptnr_logo_list01"'),
                    ('application/views/templates/footer.php', 'id="ptnr_ftr"')]:
    text = (root / rel).read_text(encoding='utf-8')
    blk = text[text.index(marker):]
    blk = blk[:blk.index('</ul>')]
    actual = [norm(l) for l in blk.splitlines() if l.strip().startswith('<li')]
    if actual == expected:
        print(f'OK   {rel} ({len(actual)}件)')
    else:
        ok = False
        print(f'NG   {rel}: 期待{len(expected)}件 / 実際{len(actual)}件')
        for e in expected:
            if e not in actual: print('  欠落:', e[:110])
        for a in actual:
            if a not in expected: print('  余分:', a[:110])
        if sorted(actual) == sorted(expected): print('  (順序のみ不一致)')
    rel_srcs = [m for l in actual for m in re.findall(r'src="(/[^"]*)"', l)]
    if rel_srcs:
        ok = False; print('NG   相対パス画像あり:', rel_srcs)
sys.exit(0 if ok else 1)
