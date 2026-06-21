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

### Excel生成
```bash
cd /Users/kyamady/workspace/cyclox2_docker
python3 docs/specs/entry-count-2025-26/build_xlsx.py
# 出力: tmp/20260621_entry_racers.xlsx（「通しでカウント」シートに 25-26 行を追加）
```

---

## 補足: status / entry_status のコード定義

- `racer_results.status`（`cyclox2_svr/cyclox2/app/Cyclox/Const/RacerResultStatus.php`）
  `0=DNS(出走せず)` / `1=FIN(ゴール到達)` / `2=DNF` / `3=DSQ(失格)` / `4=LapOut` / `5=80%Out`
- `entry_status`（`cyclox2_svr/cyclox2/app/Cyclox/Const/RacerEntryStatus.php`）
  `0=Normal` / `1=オープン`
