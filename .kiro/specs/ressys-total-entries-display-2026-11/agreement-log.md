# ressys-total-entries-display-2026-11 合意ログ

## 目的
data.cyclocross.jp（cyclox2res_sys）のリザルト画面に、cyclox-web の大会詳細画面と同様の「総エントリー数」を表示する（2026-11-14 人間依頼）。
ressys にはこの数を出すロジックがなかった（レース単位の「エントリー」人数は `Result_model::get_results` の件数で、リザルトのある選手のみ）。

## 合意事項（最終形、2026-11-17 確定）
1. 定義は cyclox-web と同じ: 大会の全 entry_groups → entry_categories → entry_racers の件数。`racer_results` は結合しない（リザルト未登録のエントリーも含む）。
   - web 側は Meet/EntryGroup/EntryCategory/EntryRacer すべて `Utils.SoftDelete`（find 時に deleted=0 を自動付与）。ressys では各テーブルの `deleted=0` を明示して一致させる。
2. 表示位置: レース画面（`race/view`）の昇格者表（「昇格者なし」表示含む）の直後、カテゴリータブ（`#cat_tab`）の直前。文言は web と同じ「総エントリー数:◯人」の1行。装飾（見出し化・アイコン・文字サイズ・余白の指定）は行わず、既存の段落スタイルのまま。ただしカテゴリータブとの間には `<br>` で1行あけて改行する（2026-11-17 人間指示）。
3. 大会トップ（`meet/view`）には表示しない。
4. 対象は `Race::view` と `views/race/view.php` のみ。旧画面 `view__` / `race/__view.php` は昇格表・タブが無く、`/race/{id}` からは使われないため対象外。

## 変更内容（cyclox2res_sys、ブランチ feat/total-entries-display、PR #26）
- `application/models/Race_model.php`: `get_total_entries_of_meet($meet_code)` を追加。
- `application/controllers/Race.php`: `view()` で `$data['total_entries']` を設定。
- `application/views/race/view.php`: 昇格表の下・タブの上に `<p class="total_entries">総エントリー数:◯人</p>` を表示。

## 表示位置・スタイルの検討経緯（2026-11-14〜17）
以下を試したが、最終的に全て取りやめ、上記2の形に戻した。
1. 昇格表の下・タブの上に1行表記（初版）。タブとの間に1行あきを追加。
2. 大会名の直下・昇格者見出しの上へ移動（大会単位の値のため）。大会名とのバランスから文字サイズ 0.8em・左端 4px 揃えを調整。
3. 「総エントリー数」をアイコン付き見出し（`h2.ttl_rankup` + `fa-users`）にして、改行して人数を表示。
→ 2026-11-17 人間指示により、位置は昇格者の下・タブの上、演出（余白・サイズ・見出し化・アイコン）は全て省くことで確定。

## 表示が遅い件の調査（2026-11-14）
- ページ全体は 12.2秒（変更前）→ 12.3秒（変更後）。**今回の追加は約0.1〜0.3秒で、遅さの原因ではない**（既存の遅さ）。
- 主因は既存クエリの全表走査: `get_laps_of_ecat`（time_records 77万行、約5秒）、`get_psrmap_of_ecat`（point_series_racers、約4.5秒）、`get_results`（racer_results 35万行、約1.7秒）。ローカルDBは外部キー列に索引が無い。
- 索引追加の調査・設計は別タスク（cyclox2_docker PR #95、`.kiro/specs/ressys-db-index-perf-2026-11/`）で実施済み。

## マージ
- cyclox2res-sys PR #26 を 2026-11-17 までにマージ（スカッシュ、`71fb00e`）。cyclox2_docker のサブモジュール参照を `71fb00e` に更新。
- 本番に出すのは res-sys のみ。cyclox2（CakePHP）はリリース不要。
- 本番反映後の確認事項: KNS-267-003 で web の総エントリー数（653人）と ressys の表示が一致すること。
