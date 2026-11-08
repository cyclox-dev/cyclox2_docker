# partner-banners-galfer-rdcx-2026-11 合意ログ

## 目的
data.cyclocross.jp（cyclox2res_sys）のパートナーバナーに GALFER・RDCX を追加し、www.cyclocross.jp と揃える。

## 合意事項（2026-11-08 人間指示）
1. 追加するロゴは指示された2行（`ptnr_logo_galfer.svg` / `ptnr_logo_rdcx.svg`、リンク先はいずれも `http://www.nasktrading.biz/`）をそのまま使う。
2. 位置は Tannus の直後に GALFER → RDCX の順で並べる（正解イメージ: https://www.cyclocross.jp/partners/ ）。
3. 2026-10-03 の合意（ヘッダーとフッターを同一にする）、および前回の Tannus 追加（ressys-note-text-and-favicon-2026-10 の「追加修正」）と同様に、header.php・footer.php の両方に入れる。
4. 記録は本ディレクトリの軽量記録のみとする（Tier 0: マークアップ追加のみでロジック変更なし）。

## 変更内容（cyclox2res_sys、ブランチ fix/partner-galfer-rdcx-2026-11）
- `application/views/templates/header.php`（`#ptnr_logo_list01`）: Tannus の直後に2行追加。
- `application/views/templates/footer.php`（`#ptnr_ftr`）: 同上。
- バナーは 11件 → 13件。

## マージ
- cyclox2res-sys PR #25 を 2026-11-08 にマージ（スカッシュ、`da7abc9`）。cyclox2_docker のサブモジュール参照を `da7abc9` に更新。
- 本番に出すのは res-sys のみ。cyclox2（CakePHP）はリリース不要。
- 注: `.kiro/specs/partner-banners-2026-10/check_banners.py` のスナップショットは 2026-10-03 時点の10件のため、今回の13件では NG になる（想定どおり）。今回も www 本番を直接取得して比較した。
