# 降格処理 RUNBOOK 2026-27版（再利用手順書）

> このドキュメントは**毎シーズンの降格処理を即時実行するための手順書**です。
> 前身: `rider-demotion-2025-26/runbook.md`（2025-26シーズン向け）。本版は2026-27シーズンの
> AJOCC規則改正（残留ライン新値・系統横断残留判定・ME1単独判定例外・連動降格）を反映した
> 改訂版。次年度はこの手順をコピーし、「## 次年度の更新点」だけ差し替えれば実行できます。
>
> 2025-26版との差分は本ファイル各節の冒頭に明記する。過去シーズンの判定資産
> （`.kiro/specs/rider-demotion-2025-26/`）は変更しない。

---

## 0. 前提と全体像

降格は `category_racers` テーブルへの **UPDATE（旧所属終了）＋ INSERT（降格先付与）** で表現する。
判定は計算済みランキング `tmp_ajoccpt_racer_sets` と所属 `category_racers`、出走実績 `racer_results` から行う。
本番反映は**検証済みSQLを本番に適用する方式（A案）**。フルダンプ/レストアは使わない。

**2026-27版の変更点**: 判定を2段構成にした。第1段 `survive_flags`（自基準充足の中間表）→
第2段 `demote_all`（系統横断残留判定・ME1単独判定例外を適用した最終降格対象）。

作業の流れ:
```
ダンプ復元 → 判定(read-only, 2段構成) → 重複調査 → downlist生成 → 降格SQL生成
→ ローカル実行(TRANSACTION+検証+COMMIT、本番はCOMMIT・シミュレーションはROLLBACK)
→ 公開ランキング照合 → 本番反映(人間)
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

> **2026-27版の変更点**: 残留ラインを新値へ更新（ME2/ME3=240位、WE1=80位を新設）。
> `season_id`は実行時に必ず`seasons`テーブルで確認すること（下表の値は2026-27時点の想定）。

| 項目 | 2026-27想定値 | 取得元 |
|---|---|---|
| `season_id` | 17（実行時に必ず確認） | `SELECT id,name,start_date,end_date FROM seasons` |
| 対象期間（昇格者窓） | 2026-09-01〜2027-03-31 | シーズン期間 |
| 旧所属 `cancel_date` | 2027-03-31 | シーズン末 |
| 降格先 `apply_date` | 2027-04-01 | 翌日 |
| `reason_note` | `2026-27シーズン成績の降格処理による` | 命名踏襲 |
| 残留ライン | **ME 240/240/240位**（C2/C3が新値）, MM 80/40点（変更なし）, **WE1 80位**（新設。旧は出走ベースのみ） | **AJOCC公式(cyclocross.jp)で毎年確認**。2026-08-29確認値。実行前に必ず再確認 |

### カテゴリーマッピング（新名称 → categories.code）
| 新 | code | 降格先 | 判定 | 集計race_category(`category_races_categories`) |
|---|---|---|---|---|
| ME1 | C1 | C2 | 順位（単独判定・救済なし） | C1, UCIME, UCIME+U |
| ME2 | C2 | C3 | 順位（CM1との系統横断救済あり） | C2 |
| ME3 | C3 | C4 | 順位（CM2との系統横断救済あり） | C3, C3+4 |
| MM1 | CM1 | CM2 | 点数（C2またはC1との系統横断救済あり） | CM1, CM1+2+3 |
| MM2 | CM2 | CM3 | 点数（C3との系統横断救済あり） | CM1+2+3, CM2, CM2+3 |
| WE1 | CL1 | CL2 | **順位（新設）**＋今季昇格除外は出走ベースも併用 | CL1, **UCIWE** |

### 対応ペア定義（me-mm-linkage-2026-27 CategoryLineageMapを出典とする複製）
| ペア | 救済関係 |
|---|---|
| C2 ⇔ CM1 | 一方が充足すれば両方残留。両方不充足なら両方降格（連動降格） |
| C3 ⇔ CM2 | 同上 |
| C1 → CM1（非対称） | C1（ME1）はCM1による救済を受けない。CM1はC1が充足していれば救済される |

> ⚠️ 次年度はカテゴリー追加・基準方式変更（順位⇄点数）・対応表そのものの変更がありうる。
> `categories` と `entry_categories.name` と公式ルール、および
> `me-mm-linkage-2026-27` の `CategoryLineageMap` で再確認すること
> （CategoryLineageMap変更時は本書・`sql/`資産の追随が必要。Revalidation Trigger）。

---

## 3. 判定基準

> **2026-27版の変更点**: 従来の3基準に加え、系統横断残留判定・ME1単独判定例外・
> 連動降格を導入した（design.md「判定セット生成SQL」参照）。

1. **基準1（自基準: 順位/点数）**: ME/WE1=順位ライン以下で残留、MM=合計点 ライン以上で残留。
   境界は「以下/以上」（残留基準ちょうどは残留）。
2. **基準2（無出走）**: 所属だが当該シーズン未出走は自基準不充足として扱う。
   - ME/MM: **全国版ランキング不在**で判定（UCI・混走も自動集計される）。
   - WE1: 順位ライン判定に加え、出走照合（`races_category_code IN ('CL1','UCIWE')`,
     `status<>0`）を参考出力として確認する。
3. **基準3（昇格者除外）**: 今季昇格（`reason_id=2`, `apply_date` 窓内, `cancel_date IS NULL`,
   `deleted=0`）は自基準を満たすものとして扱う。
4. **【新設】系統横断残留判定**: C2⇔CM1・C3⇔CM2のいずれかのペアを有効保有している選手は、
   自基準を満たさなくても、対応ペア側が自基準（または今季昇格）を満たしていれば残留する。
5. **【新設】ME1単独判定例外**: C1（ME1）はC1自身の基準1〜3のみで判定する。CM1保有・充足に
   よる救済は行わない。
6. **【新設】連動降格**: 系統横断残留判定を適用してもなお両方が不充足の対応ペアは、両方とも
   降格する（例: C2もCM1も自基準不充足→C2はC3へ、CM1はCM2へ、同時に降格）。

### 重要な落とし穴（過去に踏んだ・2025-26から継承）
- **WE1の出走はUCIWEを含める**（2025-26で日吉愛華を誤計上→修正）。各カテゴリーの集計対象は `category_races_categories` で必ず確認。
- 合計ポイント = `sumup_json` 先頭要素。MySQL5.7では `CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(sumup_json,'[',-1),',',1) AS DECIMAL(10,2))`。
- 全国版 = `ajoccpt_local_setting_id IS NULL`（地域シリーズを混ぜない）。`type=1` がデータ行（0はヘッダ）。
- `racer_results.status`: 0=DNS（出走せず）。出走は `status<>0`。
- 年齢別カテゴリー自動付与（reason_id=1, 未来日 apply_date, MM35〜MM100/WM）は重複ノイズ。`apply_date<=今日` で除外。

### 【2026-27版・新規の落とし穴候補】
- 系統横断救済の判定は「対応ペア上の正当な組み合わせのみ」を対象とする。対応外ペア
  （例: C3とCM1の同時保有）は救済に使わない（`survive_flags`結合時の`category_racers`条件で
  対応ペアのカテゴリーコードを明示的に指定していることを確認）。
- 連動降格が正しく機能しているかは、`demote_all`に同一racerが対応ペア分の2行で入っている
  ことで確認する（`sql/01_build_demote_set.sql`末尾の「連動降格ペア数」出力を参照）。
- **C1+CM1連動降格の副作用（要人間認識・コード修正ではない）**: C1（ME1）とCM1（MM1）を
  両方保有する選手が両方不充足で連動降格すると、降格先はC2+CM2の組み合わせになる。この
  組み合わせは`CategoryLineageMap`上の正当な対応ペア（C2⇔CM1, C3⇔CM2）のどちらにも
  該当しない。つまりこの選手は以後、系統横断救済の対象外（対応ペアなし）の状態でC2・CM2に
  在籍することになる。これはAJOCC規則上許容される状態と考えられるが、翌年度以降の
  `sql/01_build_demote_set.sql`実行時に「対応外ペアの同時保有」として`catracer-cleanup-2026-27`
  （未実装、別spec）のクリーンアップ対象データを生成しうる。次年度の担当者はこの種の
  レコードが異常データではなくAJOCC規則に基づく想定内の状態であることを認識しておくこと。

---

## 4. 重複（終了漏れ）調査・異常判定の再定義

> **2026-27版の変更点**: 「二重降格」の定義を変更した。対応ペアの連動降格
> （C2+CM1, C1+CM1, C3+CM2の同時降格）は**正常系**として扱い、それ以外の組み合わせでの
> 複数降格のみを異常とする（`sql/01_build_demote_set.sql`・`sql/03_verify.sql`参照）。

降格に影響するのは「降格元カテゴリーに二重所属し、両方が降格条件を満たす（＝異常な重複降格）」
ケースのみ。`sql/01_build_demote_set.sql` 実行後に異常判定を確認する
（末尾の「異常な重複降格」クエリ、対応ペア以外の組み合わせのみ抽出）。
- 同一カテゴリー多重行（C1×2等）は降格UPDATEが全アクティブ行を終了するため**対応不要**。
- C4/CM3/CL3のみの重複は降格に無関係 → 見送り。
- 過去シーズンの重複修正事例は `rider-demotion-2025-26/agreement-log.md` 参照。

---

## 5. downlist・降格SQL生成（`sql/` スクリプト）

```bash
# 5-1. 判定セットを作成（パラメータはファイル冒頭で年次調整）
docker cp .kiro/specs/season-rules-2026-27/sql/01_build_demote_set.sql cyclox2_mysql:/tmp/
docker exec -e MYSQL_PWD cyclox2_mysql sh -c 'mysql -u root cyclox2 < /tmp/01_build_demote_set.sql'

# 5-2. downlist 出力（カテゴリー別 racer_code）
#   demote_all テーブルから src 別に出力（02_gen_koukaku.sh内のemit_downlistが行う）

# 5-3. 降格SQL生成
bash .kiro/specs/season-rules-2026-27/sql/02_gen_koukaku.sh <出力先dir>
#   → c1/c2/c3/m1/m2/we1_koukaku.sql（INSERT降格先 + UPDATE旧終了）

# 5-4. 重複修正SQL（必要時）を 00_dup_fix.sql として用意し、該当racerを downlist から除外
#   （対応ペアの連動降格は除外しない。対応ペア以外の異常な重複のみ対象）
```

---

## 6. ローカル実行（TRANSACTION + 検証 + シミュレーションはROLLBACK・本番適用時のみCOMMIT）

順序: `00_dup_fix.sql` → c1 → c2 → c3 → m1 → m2 → we1。各カテゴリーで:
```sql
START TRANSACTION;
SOURCE /tmp/<cat>_koukaku.sql;
-- 検証: 降格先INSERT件数 = 期待N
SELECT COUNT(*) FROM category_racers
 WHERE category_code='<DEST>' AND reason_id=4 AND reason_note='<NOTE>' AND apply_date='<APPLY>';
-- 先頭・末尾 racer の所属状態を目視
ROLLBACK;  -- シミュレーション時（本番DBに変更を残さない）
-- COMMIT;  -- 本番適用時のみ、人間の最終確認後に実行
```

> **重要**: ローカルダンプでのシミュレーション（本節）は必ず`ROLLBACK`で終える。`COMMIT`は
> 本番反映（§9）でのみ、人間が最終確認したうえで実行する。
>
> **同一セッション実行の必須要件**: `03_verify.sql`（§7）による検証は、MySQLのデフォルト
> 分離レベル（REPEATABLE READ）のもとでは、上記`START TRANSACTION`〜`ROLLBACK`と**同一の
> mysqlセッション内**で実行しなければならない。別の`docker exec`呼び出し（＝別コネクション）
> から実行すると、未コミットのINSERT/UPDATEが一切見えず、検証項目が全て「0件＝異常なし」を
> 返してしまい、実際には判定ロジックの不具合があっても検出できない。シミュレーション時は
> 対話的な`mysql`シェルを1つ開いたまま、その中で`SOURCE`コマンドを使って各SQLを順に実行する
> こと（下記コマンド例参照）。

```
docker cp .kiro/specs/season-rules-2026-27/sql/03_verify.sql cyclox2_mysql:/tmp/
docker exec -it -e MYSQL_PWD cyclox2_mysql mysql -u root cyclox2
-- 上記で開いた対話シェル内で、同一セッションのまま:
mysql> START TRANSACTION;
mysql> SOURCE /tmp/00_dup_fix.sql;
mysql> SOURCE /tmp/c1_koukaku.sql;
mysql> -- ...c2/c3/m1/m2/we1も同様...
mysql> SOURCE /tmp/03_verify.sql;
mysql> ROLLBACK;  -- シミュレーション時。本番適用時のみ COMMIT;
```

---

## 7. 最終検証（`sql/03_verify.sql`）

> 実行方法は§6の「同一セッション実行の必須要件」を参照（別コネクションでの実行は誤って
> 「異常なし」と判定されるため不可）。

- 降格先別件数
- 異常な重複降格（対応ペア以外での複数計上）0件
- 連動降格（対応ペアの同時降格）件数の確認（正常系として表示されるのみで異常ではない）
- 連動降格ペアの降格先が対応表上の正当なペアであること（違反0件）
- 降格者の旧カテゴリー残存 0件
- WE1(CL1)集計対象race_category一覧にUCIWEが含まれることの目視確認

---

## 8. 公開ランキング照合

`https://data.cyclocross.jp/ajocc_ranking/<season_id>/0/<CODE>` と突合:
- 残留ライン位置（赤線）、☆（今季昇格＝基準3残留）、点数境界。
- **【2026-27新規】WE1(CL1)の80位境界**を新たに照合する（従来は出走ベースのみで順位境界が
  存在しなかった）。
- **【2026-27新規】系統横断救済が適用された選手のサンプル**を抽出し、両系統のランキング・
  所属と突合する。
- WebFetchは赤線（視覚）を取れないが☆・順位・点数は取得可。DB側の境界判定（氏名付き）と1件ずつ照合する。
- **ここで判定ロジックの欠陥が見つかることがある（2025-26のUCIWE取りこぼし検出例）**。必ず実施。

---

## 9. 本番反映（A案・人間が実施）

1. 本番DBバックアップ取得。
2. 検証済み `00_dup_fix.sql` → `*_koukaku.sql` をカテゴリー単位TRANSACTIONで適用、`COMMIT`前確認。
3. 適用後、降格先別件数・異常な重複降格0を本番で再確認。ressysランキング表示を確認。
4. 本番反映の判断・`COMMIT`実行は**人間のみ**が行う。過去シーズンの判定資産
   （`.kiro/specs/rider-demotion-2025-26/`）は変更しない。

---

## 出力先・PII取り扱い

downlist・降格SQL・実行ログの出力先はgit管理外（`.kiro/specs/season-rules-2026-27/outputs/`等）
とする。選手氏名・所属等のPIIを含むため、`.gitignore`での除外を確認したうえで作業すること。

---

## 次年度の更新点（ここだけ差し替える）

1. `season_id` / 期間 / `cancel_date` / `apply_date` / `reason_note`（`sql/01_build_demote_set.sql` 冒頭の変数）。
2. 残留ライン（ME順位・MM点数・WE1基準）を**AJOCC公式で確認**して置換。
3. **対応表（C2⇔CM1, C3⇔CM2, C1→CM1）に変更が無いか、`me-mm-linkage-2026-27`の
   `CategoryLineageMap`（`app/Cyclox/Const/CategoryLineageMap.php`）で確認する**
   （Revalidation Trigger。対応表が変わった場合、`sql/01_build_demote_set.sql`の
   系統横断救済ロジック・`sql/03_verify.sql`の正当ペア一覧の両方を追随させる必要がある）。
4. カテゴリー構成・判定方式の変更有無（`categories` と公式ルール）。
5. 各ランキングの集計対象 `races_category_code`（`category_races_categories`）を再確認（UCI区分の増減）。
6. 重複（異常な重複降格）の有無を再調査。

---

## 参考: 過去事例の所在
- `tmp/20230427降格処理/`（22-23, `sql_build.sh`/downlist/koukaku）
- `tmp/20240502降格処理/`（23-24, `make_sql.py`/downlist）
- `.kiro/specs/rider-demotion-2025-26/`（25-26, 系統横断残留判定導入前の最終版。
  本書はこれの改訂版）
- 本タスク成果物: `.kiro/specs/season-rules-2026-27/outputs/`（git管理外）
