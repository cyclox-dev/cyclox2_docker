# タスク: 2025-26シーズン ライダー降格処理

タスクID: `rider-demotion-2025-26`
作成日: 2026-06-20 / ステータス: **完了**（ローカル実行・検証済み／本番反映は別途人間）

## 実装タスク（実績）

### T0: 環境準備 ✅
- [x] `/tmp` 配下のダンプ（`20260613_dump.sql`）を `cyclox2_mysql` コンテナへリストア（DB=cyclox2, 33テーブル）

### T1: 手順把握・前提合意 ✅
- [x] `降格処理手順.txt` / `カテゴリ重複レーサー処理.txt` を読解、手順概要を把握
- [x] 過去事例（`tmp/20230427降格処理`, `tmp/20240502降格処理`）と突き合わせ、降格機構（reason_id=4, 旧終了+新付与）を確認
- [x] 今期残留基準（ME=240/260/280位, MM=80/40点, WE1=出走）を確定。境界は「未満」降格

### T2: データソース特定 ✅
- [x] 計算済みAJOCCポイント= `tmp_ajoccpt_racer_sets`（全国版=`ajoccpt_local_setting_id IS NULL`, type=1）を特定
- [x] 新旧カテゴリーマッピングを `entry_categories` で確認（ME1=C1 …, WE1=CL1）
- [x] 合計ポイント= `sumup_json[0]` を `ResultShell` のコードで確認

### T3: 降格判定（read-only） ✅
- [x] 3基準（順位/ポイント・無出走・今季昇格除外）で各カテゴリーの降格 racer_code を抽出
- [x] 重複（終了漏れ）調査 → 二重降格は `CCM-000-7350` 1件のみと判明
- [x] WE1出走判定を `racer_results`(status<>0) で実装

### T4: 公開ランキング照合 → バグ検出・修正 ✅
- [x] ME3/C1/C2/CM1/CM2/CL1 を公開ランキングと境界・☆・点数で照合 → 一致
- [x] **WE1の出走判定が `CL1` のみで UCIWE を取りこぼし → `日吉愛華`(TKI-156-0175) を誤計上**
- [x] 出走判定を `races_category_code IN ('CL1','UCIWE')` に修正 → WE1降格 21→20名

### T5: downlist / 降格SQL 生成（ファイル出力のみ） ✅
- [x] `c1/c2/c3/m1/m2/we1_downlist.txt` を生成
- [x] `gen_koukaku.sh` 相当で `*_koukaku.sql` を生成（INSERT降格先 + UPDATE旧終了）
- [x] `00_dup_fix.sql`（CCM-000-7350 のCM1終了）を生成

### T6: ローカル実行・検証 ✅
- [x] `00_dup_fix.sql` 実行（1行）
- [x] c1(93)→c2(107)→c3(202)→m1(48)→m2(113)→we1(20) をTRANSACTION+COMMIT、各投入件数を検証
- [x] 最終検証: 降格先別 93/107/202/48/113/20=**583**、二重降格0、旧カテゴリー残存0、CCM-000-7350=CM3のみアクティブ

### T7: SDDドキュメント整備 ✅
- [x] `.kiro/specs/rider-demotion-2025-26/`（requirements/design/tasks/spec.json/agreement-log/tech-requirements/test-results/integration-test-checklist/runbook。2026-07-19 `docs-spec-legacy-migration-2026-07` で本ディレクトリへ集約統合）
- [x] 再利用スクリプトを `.kiro/specs/rider-demotion-2025-26/sql/` に整備
- [x] PII成果物（downlist/koukaku/exec_log）を `outputs/`（git管理外）へ保存

### T8: 本番反映（人間） ⏳
- [ ] 検証済みSQL（`00_dup_fix.sql` → `*_koukaku.sql`）を本番にカテゴリー単位TRANSACTIONで適用
- [ ] 適用後、降格先別件数の最終確認

## 次年度に向けた引き継ぎ
- 手順・チェックリストは `.kiro/specs/rider-demotion-2025-26/runbook.md` に集約。
- 残留基準（順位/点数ライン）は毎年AJOCC公式を参照して更新。runbookの「次年度の更新点」を参照。
