# テスト結果記録: 2025-26シーズン エントリー数・出走数 集計

| 項目 | 内容 |
|---|---|
| タスクID | `entry-count-2025-26` |
| 実行日 | 2026-06-21 |
| 実行者 | Claude Code |
| テストフレームワーク | SQL 直接実行（集計検算） |
| 実行コマンド | `docker exec cyclox2_mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" cyclox2 -e "<query>"` |
| 実行環境 | Docker / ローカル（`cyclox2_mysql` コンテナ） |

> 接続情報は `.env` の `MYSQL_ROOT_PASSWORD` を環境変数で注入。平文をドキュメントに記載しない（CLAUDE.mdルール10）。

---

## テスト項目一覧

| # | テスト項目名 | 観点 | 期待結果 | 実際結果 | 合否 |
|---|---|---|---|---|---|
| 1 | 24-25 entry 再現 | 検算（正常系） | 参照既知値 21,644 と一致 | 21,644 | ✅ |
| 2 | 24-25 started 再現 | 検算（正常系） | 参照既知値 19,094 と一致 | 19,094 | ✅ |
| 3 | 25-26 entry 算出 | 正常系 | 同一ロジックで算出 | 21,604 | ✅ |
| 4 | 25-26 started 算出 | 正常系 | 同一ロジックで算出 | 18,802 | ✅ |
| 5 | racer_results.status 分布 | 定義検証 | status=0=DNS のみ除外される | DNS 2,508 除外、出走 18,802（=1+2+4+5） | ✅ |
| 6 | entry_status 分布 | 定義検証 | Normal以外（オープン）件数把握 | Normal 21,604 / オープン 22 | ✅ |
| 7 | 削除/未登録選手による除外件数 | 境界・既知弱点 | 25-26で0件であること | no_racer_row 0 / racer_deleted 0 | ✅ |
| 8 | started 二重カウント | 異常系 | 1エントリーに複数結果が無いこと | 0件 | ✅ |
| 9 | 期間境界の大会 | 境界値 | 04-01ちょうどの大会が無いこと | 0件 | ✅ |

---

## 実行結果サマリー

| 合計 | 合格 | 失敗 | スキップ |
|---|---|---|---|
| 9 | 9 | 0 | 0 |

**結論**: 24-25 を entry/started ともに**完全一致**で再現でき、集計方法の妥当性が確認された。
同一ロジックで 25-26 を算出した結果は entry **21,604** / started **18,802**（前年比 entry **-40** / started **-292**）。

---

## 集計結果（最終）

| シーズン | entry | started | 前年比 entry | 前年比 started |
|---|---|---|---|---|
| 24-25 | 21,644 | 19,094 | — | — |
| 25-26 | 21,604 | 18,802 | -40 | -292 |

---

## シーズン別 時系列（全期間・参照ファイル非依存の保全用）

参照ファイル `tmp/20250416_entry_racers.xlsx` にのみ存在していた過去シーズンの値を、
資料内で自己完結させるためここに転記する。**`build_xlsx.py` の `SERIES` 定数がこの表の正本**であり、
来年以降は両者に1行ずつ追記する（値は Runbook の SQL で算出）。

| シーズン | entry | started |
|---|---|---|
| 15-16 | 18,458 | 15,074 |
| 16-17 | 20,088 | 16,411 |
| 17-18 | 21,266 | 17,252 |
| 18-19 | 21,716 | 18,721 |
| 19-20 | 21,825 | 18,387 |
| 20-21 | 11,973 | 10,511 |
| 21-22 | 18,841 | 16,313 |
| 22-23 | 21,508 | 18,962 |
| 23-24 | 22,052 | 19,111 |
| 24-25 | 21,644 | 19,094 |
| 25-26 | 21,604 | 18,802 |

> 20-21 が落ち込んでいるのは COVID-19 による大会中止・縮小の影響。
> 前年比は `当年 − 前年`（entry同士・started同士）。

---

## 出力フォーマット仕様（「通しでカウント」シート）

参照ファイルが無くてもシートを再現できるよう、列・行構成を明文化する。

| 行 | B | C | D | E | F |
|---|---|---|---|---|---|
| 3 |  |  |  | `前年比` |  |
| 4 |  | `entry` | `started` | `entry` | `started` |
| 5〜 | シーズン | entry（数値） | started（数値） | 前年比entry（数式） | 前年比started（数式） |

- データは**行5から**開始（15-16が行5）。1シーズン＝1行で下へ追加。
- C・D・E・F は表示書式 `#,##0`。
- E・F（前年比）は数式 `=C{r}-C{r-1}` / `=D{r}-D{r-1}`。**先頭行（行5）は前年が無いため空**。
- 列幅: B=6.6 / C=7.6 / D=8.6 / E=7.2 / F=8.6。
- ブックは `fullCalcOnLoad=True` を設定し、Excel起動時に数式を再計算させる。

---

## Runbook（再現手順）

任意のシーズンで再現可能。`$S`/`$E` を `YYYY-04-01` 形式で指定する（例: 25-26 は `S=2025-04-01`, `E=2026-04-01`）。

```bash
cd /Users/kyamady/workspace/cyclox2_docker
set -a; . ./.env; set +a            # MYSQL_ROOT_PASSWORD を読み込み
S=2025-04-01; E=2026-04-01           # 集計対象シーズンの期間
M(){ docker exec cyclox2_mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" cyclox2 -N -e "$1"; }

# entry数
M "SELECT count(*) FROM entry_racers er
   INNER JOIN entry_categories ec ON ec.id=er.entry_category_id
   INNER JOIN entry_groups eg ON eg.id=ec.entry_group_id
   INNER JOIN meets ON meets.code=eg.meet_code
   INNER JOIN racers ON racers.code=er.racer_code
   WHERE er.deleted=0 AND ec.deleted=0 AND eg.deleted=0 AND meets.deleted=0 AND racers.deleted=0
     AND at_date>'$S' AND at_date<'$E' AND er.entry_status=0;"

# started数
M "SELECT count(*) FROM entry_racers er
   INNER JOIN entry_categories ec ON ec.id=er.entry_category_id
   INNER JOIN entry_groups eg ON eg.id=ec.entry_group_id
   INNER JOIN meets ON meets.code=eg.meet_code
   INNER JOIN racers ON racers.code=er.racer_code
   INNER JOIN racer_results rr ON rr.entry_racer_id=er.id
   WHERE er.deleted=0 AND ec.deleted=0 AND eg.deleted=0 AND meets.deleted=0 AND racers.deleted=0
     AND at_date>'$S' AND at_date<'$E' AND er.entry_status=0 AND rr.status!=0 AND rr.deleted=0;"
```

### Excel生成（2モード）

`build_xlsx.py` は参照ファイルの有無に応じて2モードを持つ。集計値は同スクリプトの `SERIES` 定数を正本とする。

```bash
cd /Users/kyamady/workspace/cyclox2_docker

# (1) テンプレートモード（既定）: 既存ブック（参照 or 前年出力）に最新行を追記、全シート温存
python3 .kiro/specs/entry-count-2025-26/build_xlsx.py --season 25-26
#   出力: tmp/20260621_entry_racers.xlsx

# (2) from-scratch モード: 参照ファイル不要。SERIES から「通しでカウント」を1枚ゼロ生成
python3 .kiro/specs/entry-count-2025-26/build_xlsx.py --from-scratch
#   出力: tmp/entry_racers_25-26_from_scratch.xlsx
```

### 来年（26-27）の手順
1. Runbook の SQL を `S=2026-04-01 E=2027-04-01` で実行し entry/started を算出。
2. `build_xlsx.py` の `SERIES` と本資料「時系列」表に `("26-27", entry, started)` を追記。
3. 前年（25-26）をローカルDBで再現して一致を確認（検算）。
4. テンプレートモードは `--src` に**前年の出力ブック**を指定して追記、または from-scratch で再生成。
   ```bash
   python3 .kiro/specs/entry-count-2025-26/build_xlsx.py \
     --src tmp/20260621_entry_racers.xlsx --season 26-27 --out tmp/26-27_entry_racers.xlsx
   ```

---

## 参考: 大会×カテゴリ別 内訳クエリ（参照ファイル `sql` シート由来）

「通しでカウント」の総数集計には不要だが、参照ファイルの「大会ごと/選手ごと」内訳シートを
再現する際に使う（参照ファイル消失時の保全用に転記）。`group by` 以外は総数クエリと同条件。

```sql
-- entry 内訳（大会×カテゴリ）
SELECT count(*), ec.races_category_code, meets.code, meets.short_name, meets.at_date
FROM entry_racers er
  INNER JOIN entry_categories ec ON ec.id=er.entry_category_id
  INNER JOIN entry_groups eg ON eg.id=ec.entry_group_id
  INNER JOIN meets ON meets.code=eg.meet_code
  INNER JOIN racers ON racers.code=er.racer_code
WHERE er.deleted=0 AND ec.deleted=0 AND eg.deleted=0 AND meets.deleted=0 AND racers.deleted=0
  AND er.entry_status=0 AND at_date>'$S' AND at_date<'$E'
GROUP BY meets.code, ec.races_category_code;

-- started 内訳（大会×カテゴリ）: 上記に racer_results を内部結合
SELECT count(*), ec.races_category_code, meets.code, meets.short_name, meets.at_date
FROM entry_racers er
  INNER JOIN entry_categories ec ON ec.id=er.entry_category_id
  INNER JOIN entry_groups eg ON eg.id=ec.entry_group_id
  INNER JOIN meets ON meets.code=eg.meet_code
  INNER JOIN racer_results rr ON er.id=rr.entry_racer_id
  INNER JOIN racers ON racers.code=er.racer_code
WHERE er.deleted=0 AND ec.deleted=0 AND eg.deleted=0 AND meets.deleted=0 AND racers.deleted=0
  AND er.entry_status=0 AND rr.deleted=0 AND rr.status!=0 AND at_date>'$S' AND at_date<'$E'
GROUP BY meets.code, ec.races_category_code;
```

> 既知の注意（参照ファイルのメモより）: 内訳クエリで `racers` を内部結合 + `racers.deleted=0` とすると、
> 削除済み/未登録選手のエントリーが除外され、年によっては総数クエリと内訳合計がずれる。
> 25-26 は該当0件のため影響なし（テスト項目#7）。

---

## 補足: status / entry_status のコード定義

- `racer_results.status`（`cyclox2_svr/cyclox2/app/Cyclox/Const/RacerResultStatus.php`）
  `0=DNS(出走せず)` / `1=FIN(ゴール到達)` / `2=DNF` / `3=DSQ(失格)` / `4=LapOut` / `5=80%Out`
- `entry_status`（`cyclox2_svr/cyclox2/app/Cyclox/Const/RacerEntryStatus.php`）
  `0=Normal` / `1=オープン`
