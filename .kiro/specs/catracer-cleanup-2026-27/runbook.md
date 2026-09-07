# catracer-cleanup-2026-27 本番適用 RUNBOOK

> このドキュメントは対応外ペア（旧系統の所属が有効なまま残っている選手）を是正する
> `CatRacerCleanupShell`（`cake cat_racer_cleanup`）の本番適用手順書。
> me-mm-linkage-2026-27（対応ペア両保有モデル）の運用開始前提として、既存データの
> 是正を1回限り実施する想定。

---

## 0. 前提と全体像

対象は `category_racers` テーブル。是正は **UPDATE（反対系統の旧保有を終了）＋
INSERT（対応カテゴリーの新規付与）** で表現し、物理削除は行わない。
判定基準は選手の**直近出走実態**（`racer_results`/`entry_racers` 経由）。

作業の流れ:
```
バックアップ → detect（検出のみ） → cleanup logonly（試算） → 人間確認
→ cleanup（本実行） → verify（違法ペア残存確認） → 残存分の後続対応
```

`cleanup`/`detect`/`verify` はいずれも冪等（再実行しても既に是正済みの選手には影響しない）。

---

## 1. 環境準備（バックアップ）

```bash
export MYSQL_PWD="$(grep -E '^MYSQL_ROOT_PASSWORD=' .env | cut -d= -f2-)"
docker exec -e MYSQL_PWD cyclox2_mysql sh -c \
  'mysqldump -u root cyclox2 category_racers > /tmp/category_racers_backup_$(date +%Y%m%d%H%M%S).sql'
docker cp cyclox2_mysql:/tmp/category_racers_backup_<timestamp>.sql ./
```

`category_racers` 単体のバックアップで十分（本バッチはこのテーブルのみ書き込む）。

---

## 2. 検出（detect、書き込みなし）

```bash
docker exec cyclox2_svr bash -lc \
  "cd /var/www/html/app && ../lib/Cake/Console/cake cat_racer_cleanup detect"
```

出力末尾の集計行（違法保有選手数・件数）と、専用ログ
`app/tmp/logs/catracer_cleanup.log` を確認する。

---

## 3. 試算（cleanup logonly、書き込みなし・全ロールバック）

```bash
docker exec cyclox2_svr bash -lc \
  "cd /var/www/html/app && ../lib/Cake/Console/cake cat_racer_cleanup cleanup '' '' logonly"
```

集計行（`検出選手数 FIX MANUAL DUP_ONLY OK 終了件数 付与件数`）を記録する。
**MANUAL判定の選手一覧を専用ログから抽出し、人間が個別に確認する**
（出走実績なし・系統判定不能・同日両系統タイ等、自動是正しない理由が明細に付く）。

**DUP_ONLY（完全重複起因）判定の選手は本バッチの対象外。** 既存の
`OneTimeShell::setupDuplicatedCatRacerDeleted()` 等、重複是正の既存手段で別途対応する
（brief.mdのOut of Boundary／agreement-logの却下・保留事項）。

---

## 4. 人間確認ゲート

**この時点で必ず一旦停止し、人間が以下を確認してから次に進める:**
1. FIX件数・是正内容（正系統維持／終了カテゴリー／付与カテゴリー）が想定通りか
2. MANUAL一覧を確認し、緊急対応が必要な選手がいないか
3. バックアップが取得済みであること

---

## 5. 本実行（cleanup、実書き込み）

```bash
docker exec cyclox2_svr bash -lc \
  "cd /var/www/html/app && ../lib/Cake/Console/cake cat_racer_cleanup cleanup"
```

集計行がstep 3の試算と完全一致することを確認する（一致しない場合はstep 2以降のデータが
実行間に変化した可能性があり、原因を調査してから再実行すること）。

**チャンク実行する場合は必ず `offset=0` から毎回掃引すること。**
`cleanup` の是正確定により「検証済み違法選手リスト」自体が縮小するため、
`offset` をずらして分割すると対象を取りこぼす（tasks.md task 3.1/4.2申し送り）。

---

## 6. 検証（verify、書き込みなし）

```bash
docker exec cyclox2_svr bash -lc \
  "cd /var/www/html/app && ../lib/Cake/Console/cake cat_racer_cleanup verify"
```

残存する違法保有は、step 3で確認したMANUAL・DUP_ONLYの合計件数と一致するはずである
（新規の残存があれば異常）。「違法ペアゼロ」はFIX対象に限っては達成される。

---

## 7. 残存分の後続対応

- **MANUAL（人間確認対象）**: `outputs/manual-review-list.md`（またはstep 3のログ）の
  一覧を元に、選手ごとに個別確認・手動でのcategory_racers是正を検討する。
- **DUP_ONLY（完全重複）**: 既存の重複是正手段で別途対応する（本specのスコープ外）。

両対応の完了をもって、me-mm-linkage-2026-27運用開始前提（違法ペアゼロ）を満たす。

---

## 8. ロールバック手順

`cleanup` は物理削除を行わないため、誤りが判明した場合も履歴は保全されている。
是正した行を個別に元へ戻す場合:
```sql
-- 是正で新規付与した行を無効化（削除ではなくcancel_date設定）
UPDATE category_racers SET cancel_date = '<誤りが判明した日の前日>' WHERE id = <付与行のid>;
-- 是正で終了させた旧保有を復活
UPDATE category_racers SET cancel_date = NULL WHERE id = <終了させた行のid>;
```
対象の `id` は専用ログ（`catracer_cleanup.log`）の明細（終了行ID・付与行）から特定する。
全面的なロールバックが必要な場合は step 1 のバックアップから `category_racers` を復元する。

---

## 実行実績

| 実行日 | 環境 | 検出 | FIX | MANUAL | DUP_ONLY | 備考 |
|---|---|---|---|---|---|---|
| 2026-09-07 | ローカル開発DB（`cyclox2`、267,917行規模） | 406選手/858件 | 13 | 98 | 295 | test-results.md参照 |
