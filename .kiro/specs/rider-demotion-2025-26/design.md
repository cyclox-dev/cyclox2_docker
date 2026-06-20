# 設計: 2025-26シーズン ライダー降格処理

タスクID: `rider-demotion-2025-26`
作成日: 2026-06-20

## アーキテクチャ概要

降格処理は DBのみで完結する（アプリ改修なし）。`category_racers` テーブルへの UPDATE/INSERT で表現する。
判定は `tmp_ajoccpt_racer_sets`（計算済みランキング）と `category_racers`（所属）と出走実績（`racer_results` 経由）から行う。

```
[判定入力]
  tmp_ajoccpt_racer_sets (全国版/type=1)  … 順位・合計点(sumup_json[0])
  category_racers (cancel_date IS NULL, deleted=0) … 現所属/今季昇格(reason_id=2)
  racer_results → entry_racers → entry_categories(races_category_code)
                → entry_groups → meets(season_id) … 実出走(status<>0)
        │
        ▼
[降格対象 racer_code リスト]  (カテゴリー別 downlist)
        │  gen_koukaku.sh
        ▼
[降格SQL]  *_koukaku.sql  (INSERT 降格先 + UPDATE 旧所属終了)
        │  カテゴリー単位 TRANSACTION → 検証 → COMMIT
        ▼
[category_racers 更新]  (ローカル → 本番は同SQLを適用)
```

## 主要データ構造

### `categories`（マスタ）
- PK=`code`（C1, C2, C3, C4, CM1, CM2, CM3, CL1, CL2 …）。新名称(ME/MM/WE)は別途エントリー表示名。

### `tmp_ajoccpt_racer_sets`（計算済みランキング）
- `season_id`, `category_code`(=降格元code), `type`(0=ヘッダ/1=データ), `rank`, `racer_code`,
  `ajoccpt_local_setting_id`（NULL=全国版/無印、数値=地域シリーズ）, `sumup_json`。
- **合計ポイント = `sumup_json` 配列の先頭要素**（`["合計","平均","最大","ln数"]` の合計）。
  抽出: `CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(sumup_json,'[',-1),',',1) AS DECIMAL(10,2))`。

### `category_races_categories`（ランキング集計対象の race_category マップ）
- 各降格元カテゴリーのランキングが集計する `races_category_code`:
  - C1 ← C1, UCIME, UCIME+U
  - C2 ← C2
  - C3 ← C3, C3+4
  - CM1 ← CM1, CM1+2+3
  - CM2 ← CM1+2+3, CM2, CM2+3
  - CL1 ← CL1, **UCIWE**

### `category_racers`（所属履歴）
- `racer_code`, `category_code`, `apply_date`, `reason_id`, `reason_note`, `cancel_date`, `deleted`。
- `reason_id`: 1=新規付け, **2=レース昇格**, 3=シーズン成績昇格, **4=シーズン成績降格**, 5=特別付与,
  6=年齢変更, 7=ルール変更, 8=その他昇格, 9=その他降格, 10=その他付与, 11=申請変更(Elite⇔Masters)。

### `racer_results.status`（出走判定）
- 0=出走せず(DNS), 1=ゴール到達(FIN), 2=DNF, 3=失格, 4=周回遅れLapOut, 5=80%Out。
- **出走 = status <> 0**。

## 降格判定ロジック（カテゴリー別）

母集団 = 当該カテゴリーの現所属者（`category_racers` で `cancel_date IS NULL AND deleted=0`）。

- **ME系（C1/C2/C3, 順位制）**: 残留 = 全国版ランキングに在席 かつ `rank <= ライン`。
  降格 = 母集団 − 残留 − 今季昇格(reason_id=2, 窓内)。
  （順位ライン超過＝基準1、ランキング不在＝基準2 の和集合を、昇格者除外で実装）
- **MM系（CM1/CM2, ポイント制）**: 残留 = 全国版ランキングに在席 かつ `合計点 >= 閾値`。
  降格 = 母集団 − 残留 − 今季昇格。
- **WE1（CL1, 出走制）**: 残留 = 対象シーズンに `races_category_code IN ('CL1','UCIWE')` で `status<>0` の出走あり。
  降格 = 母集団 − 残留 − 今季昇格。

> 重要: WE1の出走判定は races_category を直接見るため **UCIWE を必ず含める**。
> ME/MMは「ランキング在席」で判定するためUCI・混走は自動的に集計済み。

## 降格レコードの更新（1名あたり）

```sql
-- 降格先の付与
INSERT INTO category_racers (racer_code, category_code, apply_date, reason_id, reason_note, created, modified)
VALUES ('<racer>', '<DEST>', '2026-04-01', 4, '2025-26シーズン成績の降格処理による', now(), now());
-- 旧所属の終了（当該カテゴリーの全アクティブ行を終了 → 多重行も一括処理）
UPDATE category_racers SET cancel_date='2026-03-31', modified=now()
WHERE deleted=0 AND category_code='<SRC>' AND cancel_date IS NULL AND racer_code='<racer>';
```

## 重複（終了漏れ）対応

- 降格に影響するのは「降格元カテゴリーに二重所属し、両方が降格条件を満たす」ケースのみ。
- 2025-26では `CCM-000-7350`（CM1=2015システム初期設定の種データ + CM2=2015本人希望）の1件のみが二重降格となった。
  → 終了漏れの CM1(id=721) を `cancel_date='2026-03-31'` で終了し、実カテゴリーCM2のみ残し、CM2→CM3の1件として処理（`00_dup_fix.sql`）。
- 同一カテゴリー多重行（C1×2等）は降格UPDATEが全アクティブ行を終了するため自動処理。

## データフロー（実行）

1. `00_dup_fix.sql`（重複修正）
2. c1 → c2 → c3 → m1 → m2 → we1 の順に、各カテゴリー:
   `START TRANSACTION` → 投入 → 検証SELECT（INSERT件数=N / 先頭末尾レコード）→ `COMMIT`
3. 最終検証: 降格先別件数（合計583）、二重降格0、旧カテゴリー残存0。

## テスト方針

- アプリのユニットテスト対象外（DB操作のみ）。検証はSQLによる件数・整合性チェックで行う（`test-results.md`）。
- 外部照合: 公開ランキングと境界・☆・点数を突き合わせる（`integration-test-checklist.md`）。

## リスク・対策

| リスク | 対策 |
|---|---|
| 出走判定の取りこぼし（UCI/混走） | 集計対象 race_category を `category_races_categories` で確認し全て含める（WE1=CL1+UCIWE） |
| 二重降格 | 降格セット全体で racer 重複を検出し、終了漏れを事前修正 |
| 本番との断面ズレ | 本番ダンプ＝ローカルで検証。本番反映は同SQL適用（A案）で他データを巻き込まない |
| 残留基準の年次変更 | runbookに「公式ルール参照」を明記し、ラインを変数化 |
