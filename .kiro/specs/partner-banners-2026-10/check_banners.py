#!/usr/bin/env python3
"""data.cyclocross.jp（cyclox2res_sys）のパートナーバナーが www.cyclocross.jp と一致するか検証する。

使い方:
  python3 check_banners.py <cyclox2res_sys のパス>              # www 本番をその場で取得して比較（既定）
  python3 check_banners.py <path> --url file:///.../www.html    # 保存済みHTMLと比較（テスト用）
  python3 check_banners.py <path> --snapshot                    # 2026-10-03 時点の10件スナップショットと比較（旧方式）

比較対象:
  data 側 header.php の #ptnr_logo_list01 ↔ www の #ptnr_logo_list01
  data 側 footer.php の #ptnr_ftr         ↔ www の #ptnr_ftr（--snapshot 時はヘッダーと同じスナップショット）
比較は <li> 単位で、&amp; を & に揃え、前後の空白を除去し、www 側の相対パス画像
(src="/img/...") を https://www.cyclocross.jp/img/... に絶対URL化したうえで行う
（data 側では相対パスの画像は 404 になるため、絶対URLが正）。
NG のときは、data 側に貼り付けるべき www の <li> 全行（絶対URL化済み）を表示する。

終了コード: 0=一致 / 1=不一致・相対パス画像あり / 2=www の取得失敗・ブロック未検出
"""
import argparse
import pathlib
import re
import sys
import urllib.request
from collections import Counter

WWW = 'https://www.cyclocross.jp'
HEADER_ID = 'ptnr_logo_list01'
FOOTER_ID = 'ptnr_ftr'
TARGETS = [('application/views/templates/header.php', HEADER_ID),
           ('application/views/templates/footer.php', FOOTER_ID)]


def norm(li):
    li = li.replace('&amp;', '&').strip()
    return re.sub(r'src="/(?!/)', f'src="{WWW}/', li)


def li_lines(html, div_id):
    """id=div_id のブロック内（最初の </ul> まで）の <li> 行を返す。見つからなければ None。"""
    m = re.search(r'id="%s"' % re.escape(div_id), html)
    if not m:
        return None
    end = html.find('</ul>', m.end())
    if end < 0:
        return None
    return [l.replace('&amp;', '&').strip() for l in html[m.end():end].splitlines()
            if l.strip().startswith('<li')]


def die(msg):
    print('ERROR', msg)
    sys.exit(2)


def load_expected(args):
    here = pathlib.Path(__file__).parent
    if args.snapshot:
        snap = [l for l in (here / 'www-header-snapshot.html').read_text(encoding='utf-8').splitlines() if l.strip()]
        snap = [norm(l) for l in snap]
        return {HEADER_ID: snap, FOOTER_ID: snap}, 'スナップショット(2026-10-03)'
    try:
        req = urllib.request.Request(args.url, headers={'User-Agent': 'check_banners.py'})
        with urllib.request.urlopen(req, timeout=30) as r:
            html = r.read().decode('utf-8')
    except Exception as e:  # noqa: BLE001 - 取得失敗は理由を表示して終了
        die(f'www の取得に失敗しました: {args.url} ({e})')
    expected = {}
    for div_id in (HEADER_ID, FOOTER_ID):
        lis = li_lines(html, div_id)
        if not lis:
            die(f'www 側で #{div_id} の <li> が見つかりません（ページ構造が変わった可能性）: {args.url}')
        expected[div_id] = [norm(l) for l in lis]
    return expected, args.url


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('root', help='cyclox2res_sys のパス')
    ap.add_argument('--url', default=WWW + '/', help='比較元のURL（既定: www 本番トップ）')
    ap.add_argument('--snapshot', action='store_true', help='2026-10-03 の10件スナップショットと比較する')
    args = ap.parse_args()
    root = pathlib.Path(args.root)

    expected, source = load_expected(args)
    print(f'比較元: {source}')
    if not args.snapshot and expected[HEADER_ID] != expected[FOOTER_ID]:
        print('注意 www 側でヘッダーとフッターのバナーが異なります（それぞれと比較します）')

    ok = True
    for rel, div_id in TARGETS:
        exp = expected[div_id]
        try:
            text = (root / rel).read_text(encoding='utf-8')
        except OSError as e:
            ok = False
            print(f'NG   {rel}: ファイルが見つかりません（パス指定を確認。サブモジュール未初期化の可能性）: {e}')
            continue
        lis = li_lines(text, div_id)
        if lis is None:
            ok = False
            print(f'NG   {rel}: #{div_id} が見つかりません')
            continue
        actual = lis
        an = [norm(a) for a in actual]  # 相対パスを絶対化した形で比較（相対パス自体は下で別途 NG）
        if an == exp:
            print(f'OK   {rel} ({len(actual)}件)')
        else:
            ok = False
            print(f'NG   {rel}: 期待{len(exp)}件 / 実際{len(actual)}件')
            ce, ca = Counter(exp), Counter(an)
            for e in exp:
                if e not in ca:
                    print('  欠落:', e)
            for a, n in zip(actual, an):
                if n not in ce:
                    print('  余分:', a)
            for n in ca:
                if n in ce and ca[n] > ce[n]:
                    print(f'  重複: {n}（期待{ce[n]}回 / 実際{ca[n]}回）')
                elif n in ce and ca[n] < ce[n]:
                    print(f'  不足: {n}（期待{ce[n]}回 / 実際{ca[n]}回）')
            if sorted(an) == sorted(exp):
                print('  (順序のみ不一致)')
            print(f'  --- www と同じにするには #{div_id} の <li> を次の{len(exp)}行にする ---')
            for e in exp:
                print('  ' + e)
        rel_srcs = [m for l in actual for m in re.findall(r'src="(/(?!/)[^"]*)"', l)]
        if rel_srcs:
            ok = False
            print(f'NG   {rel}: 相対パス画像あり（data 側では 404。{WWW} の絶対URLにする）:', rel_srcs)
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
