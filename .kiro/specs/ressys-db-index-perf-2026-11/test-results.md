# テスト結果（ローカル検証）

## 環境
- ローカルDB: `cyclox2_mysql`（MySQL 5.7.42, amd64エミュレーション on arm64, バッファプール128MB）。データは検証用コピー。
- アプリ: 使い捨てコンテナ `kyamady/img_cyclox2ressys_svr`（ポート8092。8082は別セッションの確認用コンテナが使用中のため避けた）、
  `cyclox2_docker_fixed_compose_network`、models/controllers/views はメインチェックアウトのサブモジュール(`c5ad656`)をマウント。検証後にコンテナ削除済み。
- 対象レース: ecat_id=24693（576エントリー、リザルトあり）。絶対値はエミュレーションのため実環境より遅い。相対比較として見ること。

## ページ表示時間（`curl -w %{time_total}`、`/race/24693`）
| 状態 | 1回目 | 2回目 | 3回目 |
|---|---|---|---|
| ① ベースライン（索引欠落のローカル現状） | 12.14s | 12.08s | - |
| ② 本番同等の4索引を追加 | 0.54s | 0.50s | 0.44s |
| ③ ②＋本番に無い4索引を追加 | 0.24s | 0.24s | 0.24s |
| ④ 全索引を削除して復元後 | 12.04s | - | - |

## 主要クエリ（mysqlクライアント経由。`docker exec` の起動オーバーヘッド約0.1秒を含む）
| クエリ | ① | ② | ③ |
|---|---|---|---|
| q1 get_results | 1.74s | 0.10s | 0.10s |
| q2 holdpoints | 0.16s | 0.30s※ | 0.10s |
| q3 get_laps_of_ecat | 5.12s | 0.11s | 0.11s |
| q4 get_psrmap_of_ecat | 4.43s | 0.10s | 0.11s |
| q5 rankup用 rr_id取得 | 0.28s | 0.11s | 0.10s |
| q6 get_rankuppers_of_meet | 0.41s | 0.21s | 0.11s |
| q7 get_race_of_meet（一覧） | 0.12s | 0.11s | 0.10s |
| q8 get_race_of_meet（優勝者） | 0.21s | 0.10s | 0.11s |
| q9 総エントリー数 | 0.27s | 0.12s | 0.10s |

※ q2は計測ばらつき（EXPLAINは②でも `hold_points` 全走査のまま。③で索引使用）。EXPLAINの全文は `evidence/explain_*.txt`。

## EXPLAINの要点
- ①: `time_records`(約77万行)・`point_series_racers`・`racer_results`・`entry_racers` が `type=ALL`（全走査）。
- ②: 上記が索引経由（`ref`）になり、`ec.id` 起点で絞り込める。
- ③: `entry_groups.meet_code` / `entry_categories.entry_group_id` / `hold_points.racer_result_id` も索引経由。

## 追加した索引（検証用）と復元
- ②: `time_records(racer_result_id)`=in_result_id、`entry_racers(entry_category_id)`=index_entry_cat_id、
  `point_series_racers(racer_result_id)`、`category_racers(racer_result_id)`（いずれも `ALGORITHM=INPLACE, LOCK=NONE` で全て数秒以内に完了）。
- ③: `entry_categories(entry_group_id)`、`entry_categories(races_category_code)`、`entry_groups(meet_code)`、
  `hold_points(racer_result_id)`、`category_races_categories(races_category_code)`。
- 復元: 追加した索引を全て `DROP INDEX` し `ANALYZE TABLE`。`evidence/local_indexes_before.txt` と
  `local_indexes_after_restore.txt` が一致（diff差分なし）、復元後の表示時間も12.04sに戻ることを確認。

## 追加索引サイズ（ローカル実測、③の索引を含むテーブル全体のINDEX_LENGTH）
entry_categories 1.1MB / entry_groups 0.4MB / hold_points 1.9MB / time_records 26.1MB / entry_racers 14.0MB / category_racers 18.6MB / point_series_racers 3.0MB。
（本番の `index_mb` は 26/13/18/3/0/0/0 MB と整合。本番に無い4索引の増分は合計約3〜4MB。）

## 再現手順
`evidence/queries/` のSQLと `run.sh`（EXPLAIN要約＋実行時間）を使用。`q*.sql` の ecat_id は 24693 固定。
