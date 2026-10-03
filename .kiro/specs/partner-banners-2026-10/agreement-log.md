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
