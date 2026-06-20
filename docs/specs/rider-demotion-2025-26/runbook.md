# 降格処理 RUNBOOK（再利用手順書）

> このドキュメントは**毎シーズンの降格処理を即時実行するための手順書**です。
> 初出: 2025-26シーズン（`rider-demotion-2025-26`）。次年度はこの手順をコピーし、
> 「## 次年度の更新点」だけ差し替えれば実行できます。

---

## 0. 前提と全体像

降格は `category_racers` テーブルへの **UPDATE（旧所属終了）＋ INSERT（降格先付与）** で表現する。
判定は計算済みランキング `tmp_ajoccpt_racer_sets` と所属 `category_racers`、出走実績 `racer_results` から行う。
本番反映は**検証済みSQLを本番に適用する方式（A案）**。フルダンプ/レストアは使わない。

作業の流れ:
```
ダンプ復元 → 判定(read-only) → 重複調査 → downlist生成 → 降格SQL生成
→ ローカル実行(TRANSACTION+検証+COMMIT) → 公開ランキング照合 → 本番反映(人間)
```

---

## 1. 環境準備（ダンプ復元）

```bash
# 接続情報: DB=cyclox2 / user=root。パスワードは .env の MYSQL_ROOT_PASSWORD を使用する
#   （リポジトリにハードコードしない。下記のとおり環境変数 MYSQL_PWD 経由で渡す）
export MYSQL_PWD="$(grep -E '^MYSQL_ROOT_PASSWORD=' .env | cut -d= -f2-)"

# /tmp 等のダンプを cyclox2_mysql コンテナへ
docker cp <dump>.sql cyclox2_mysql:/tmp/dump.sql
docker exec -e MYSQL_PWD cyclox2_mysql sh -c 'mysql -u root cyclox2 < /tmp/dump.sql'
```

> 以降の `docker exec -e MYSQL_PWD ...` は、上で設定した環境変数 `MYSQL_PWD` を
> コンテナへ引き渡してパスワードを供給する（コマンドラインや本書に平文を残さない）。

---

## 2. 基本パラメータ（毎年確認）

| 項目 | 2025-26実績 | 取得元 |
|---|---|---|
| `season_id` | 16 | `SELECT id,name,start_date,end_date FROM seasons` |
| 対象期間（昇格者窓） | 2025-09-01〜2026-03-31 | シーズン期間 |
| 旧所属 `cancel_date` | 2026-03-31 | シーズン末 |
| 降格先 `apply_date` | 2026-04-01 | 翌日 |
| `reason_note` | `2025-26シーズン成績の降格処理による` | 命名踏襲 |
| 残留ライン | ME 240/260/280位, MM 80/40点, WE1 出走 | **AJOCC公式(cyclocross.jp)で毎年確認** |

### カテゴリーマッピング（新名称 → categories.code）
| 新 | code | 降格先 | 判定 | 集計race_category(`category_races_categories`) |
|---|---|---|---|---|
| ME1 | C1 | C2 | 順位 | C1, UCIME, UCIME+U |
| ME2 | C2 | C3 | 順位 | C2 |
| ME3 | C3 | C4 | 順位 | C3, C3+4 |
| MM1 | CM1 | CM2 | 点数 | CM1, CM1+2+3 |
| MM2 | CM2 | CM3 | 点数 | CM1+2+3, CM2, CM2+3 |
| WE1 | CL1 | CL2 | 出走 | CL1, **UCIWE** |

> ⚠️ 次年度はカテゴリー追加・基準方式変更（順位⇄点数）がありうる。
> `categories` と `entry_categories.name` と公式ルールで再確認すること。

---

## 3. 判定の3基準

1. **基準1（順位/点数）**: ME=順位ライン未満、MM=合計点 閾値未満を降格。境界は「未満」（残留基準ちょうどは残留）。
2. **基準2（無出走）**: 所属だが当該シーズン未出走を降格。
   - ME/MM: **全国版ランキング不在**で判定（UCI・混走も自動集計される）。
   - WE1: **`races_category_code IN ('CL1','UCIWE')` の `status<>0`** で出走判定（UCIWE必須）。
3. **基準3（昇格者除外）**: 今季昇格（`reason_id=2`, `apply_date` 窓内, `cancel_date IS NULL`, `deleted=0`）は対象外。

### 重要な落とし穴（過去に踏んだ）
- **WE1の出走はUCIWEを含める**（2025-26で日吉愛華を誤計上→修正）。各カテゴリーの集計対象は `category_races_categories` で必ず確認。
- 合計ポイント = `sumup_json` 先頭要素。MySQL5.7では `CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(sumup_json,'[',-1),',',1) AS DECIMAL(10,2))`。
- 全国版 = `ajoccpt_local_setting_id IS NULL`（地域シリーズを混ぜない）。`type=1` がデータ行（0はヘッダ）。
- `racer_results.status`: 0=DNS（出走せず）。出走は `status<>0`。
- 年齢別カテゴリー自動付与（reason_id=1, 未来日 apply_date, MM35〜MM100/WM）は重複ノイズ。`apply_date<=今日` で除外。

---

## 4. 重複（終了漏れ）調査

降格に影響するのは「降格元カテゴリーに二重所属し、両方が降格条件を満たす（＝二重降格）」ケースのみ。
`sql/01_build_demote_set.sql` 実行後に二重降格を検出（`HAVING COUNT(*)>1`）。
- 2025-26は `CCM-000-7350`（CM1種データ + CM2本人希望）の1件のみ → CM1(id=721)終了で解消。
- 同一カテゴリー多重行（C1×2等）は降格UPDATEが全アクティブ行を終了するため**対応不要**。
- C4/CM3/CL3のみの重複は降格に無関係 → 見送り。

---

## 5. downlist・降格SQL生成（`sql/` スクリプト）

```bash
# 5-1. 判定セットを作成（パラメータはファイル冒頭で年次調整）
docker cp docs/specs/rider-demotion-2025-26/sql/01_build_demote_set.sql cyclox2_mysql:/tmp/
docker exec -e MYSQL_PWD cyclox2_mysql sh -c 'mysql -u root cyclox2 < /tmp/01_build_demote_set.sql'

# 5-2. downlist 出力（カテゴリー別 racer_code）
#   demote_all テーブルから src 別に出力（runbook末尾の例参照）

# 5-3. 降格SQL生成
bash docs/specs/rider-demotion-2025-26/sql/02_gen_koukaku.sh <出力先dir>
#   → c1/c2/c3/m1/m2/we1_koukaku.sql（INSERT降格先 + UPDATE旧終了）

# 5-4. 重複修正SQL（必要時）を 00_dup_fix.sql として用意し、該当racerを m1/m2 downlist から除外
```

---

## 6. ローカル実行（TRANSACTION + 検証 + COMMIT）

順序: `00_dup_fix.sql` → c1 → c2 → c3 → m1 → m2 → we1。各カテゴリーで:
```sql
START TRANSACTION;
SOURCE /tmp/<cat>_koukaku.sql;
-- 検証: 降格先INSERT件数 = 期待N
SELECT COUNT(*) FROM category_racers
 WHERE category_code='<DEST>' AND reason_id=4 AND reason_note='<NOTE>' AND apply_date='<APPLY>';
-- 先頭・末尾 racer の所属状態を目視
COMMIT;  -- 問題なければ
```

---

## 7. 最終検証（`sql/03_verify.sql`）

- 降格先別件数（2025-26: 93/107/202/48/113/20=583）
- 二重降格 0件
- 降格者の旧カテゴリー残存 0件
- 重複修正対象の最終状態

---

## 8. 公開ランキング照合

`https://data.cyclocross.jp/ajocc_ranking/<season_id>/0/<CODE>` と突合:
- 残留ライン位置（赤線）、☆（今季昇格＝基準3残留）、点数境界。
- WebFetchは赤線（視覚）を取れないが☆・順位・点数は取得可。DB側の境界判定（氏名付き）と1件ずつ照合する。
- **ここで判定ロジックの欠陥が見つかることがある（2025-26のUCIWE取りこぼし検出例）**。必ず実施。

---

## 9. 本番反映（A案・人間が実施）

1. 本番DBバックアップ取得。
2. 検証済み `00_dup_fix.sql` → `*_koukaku.sql` をカテゴリー単位TRANSACTIONで適用、COMMIT前確認。
3. 適用後、降格先別件数・二重降格0を本番で再確認。ressysランキング表示を確認。

---

## 次年度の更新点（ここだけ差し替える）

1. `season_id` / 期間 / `cancel_date` / `apply_date` / `reason_note`（`sql/01_build_demote_set.sql` 冒頭の変数）。
2. 残留ライン（ME順位・MM点数・WE1基準）を**AJOCC公式で確認**して置換。
3. カテゴリー構成・判定方式の変更有無（`categories` と公式ルール）。
4. 各ランキングの集計対象 `races_category_code`（`category_races_categories`）を再確認（UCI区分の増減）。
5. 重複（二重降格）の有無を再調査。

---

## 参考: 過去事例の所在
- `tmp/20230427降格処理/`（22-23, `sql_build.sh`/downlist/koukaku）
- `tmp/20240502降格処理/`（23-24, `make_sql.py`/downlist）
- 本タスク成果物: `docs/specs/rider-demotion-2025-26/outputs/`（git管理外）
