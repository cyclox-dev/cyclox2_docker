# partner-banners-2026-10 合意ログ

## 目的
data.cyclocross.jp（cyclox2res_sys）のパートナーバナーを、www.cyclocross.jp ヘッダーの10件に揃える。

## 合意事項（2026-10-03 人間承認）
1. ヘッダーに加え**フッターも**同じ10件に揃える（www側もフッターはヘッダーと同一10件）。
2. アクトサイクの画像は www 側で相対パス(`/img/partners/...`)だが、data側では404になるため**絶対URL化**する。
3. 本件は軽量な記録（本ディレクトリ）のみ残す。

## 抽出・照合結果
- 抽出元: https://www.cyclocross.jp/ の `#ptnr_logo_list01` 内 `<li>` 10件（`www-header-snapshot.html`）。
- 人間提示のHTMLと照合 → 一致。差分は `&`/`&amp;` の表記のみ（J SPORTS utmパラメータ）。HTMLとして等価。
  data側テンプレートは従来どおり生の `&` を採用（www実ソースと同じ）。
- www側フッター(`#ptnr_ftr`)の `<li>` もヘッダーと同一であることを確認。
- スナップショットとの差分はアクトサイク画像の絶対URL化のみ。

## 変更内容（cyclox2res_sys, ブランチ fix/header-partner-banners-2026-10）
- `application/views/templates/header.php` / `footer.php` の `<li>` を11件→10件に差し替え。
  - 削除: アミノバイタル / Canyon / 田中養蜂場
  - 追加: TREK / アクトサイク
- CSS変更なし（`#ptnr_logo_list01`・`logo_size02` のスタイルはwwwの base.css 側）。

## 検証
`check_banners.py <cyclox2res_sys path>` で header/footer をスナップショットと正規化比較（件数・順序・相対パス画像の有無）。

## 追補: check_banners.py を www 直接比較に改修（2026-11-14 人間指示）
- 背景: スナップショット（2026-10-03 の10件）固定のため、Tannus（11件）・GALFER/RDCX（13件）追加のたびに必ず NG になり、毎回 www を手で取得して比較していた。
- 変更: 既定で www 本番トップをその場で取得し、header ↔ `#ptnr_logo_list01`、footer ↔ `#ptnr_ftr` をそれぞれ比較する。
  - www 側の相対パス画像は比較時に絶対URL化（data 側は絶対URLが正）。data 側に相対パス画像があれば NG。
  - NG 時は data 側に貼るべき www の `<li>` 全行（絶対URL化済み）を表示する。欠落・余分に加え、重複・不足も原因行を表示する。
  - data 側テンプレートが無い場合は Traceback ではなく NG として表示する（サブモジュール未初期化に気付けるように）。
  - 終了コード 0=一致 / 1=不一致 / 2=取得失敗・ブロック未検出。`--url` で保存HTMLと比較可、`--snapshot` で旧方式。
- 回帰テスト: `tests/test_check_banners.sh <cyclox2res_sys のパス>`（res-sys の過去コミット 94ab475 / c5ad656 / da7abc9 と `tests/fixtures/www-13.html` を使用）。
- 関連 spec: Tannus 追加は `ressys-note-text-and-favicon-2026-10`（追加修正）、GALFER/RDCX 追加は `partner-banners-galfer-rdcx-2026-11`。
