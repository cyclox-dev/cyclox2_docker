# テスト結果記録: 2025-26 新ポイントテーブル ランキングシミュレーション

| 項目 | 内容 |
|---|---|
| タスクID | `point-sim-2025-26` |
| 実行日 | 2026-06-15 |
| 実行者 | Claude Code |
| テスト方式 | Console製アサーション・ハーネス（CakePHP 2.x、PHPUnit非導入のため） |
| 実行コマンド | `Console/cake PointSim testTables` |
| 実行環境 | Docker（cyclox2_svr / PHP7.3 / CakePHP2.10.24） |

---

## 単体テスト（PointSim testTables）

**結果: PASS=32 / FAIL=0**

| 区分 | 観点 | 結果 |
|---|---|---|
| System① 非JCX | 出走人数8区分の各tier rank1値（100+→400, 40-59→350, 20-39→300, 10-19→250, 1-9→200） | ✅ |
| System① 非JCX 境界 | 人数境界(4/5,9/10,19/20,39/40,59/60,79/80,99/100)でtier切替 | ✅ |
| System① JCX | JCX列(rank1=1000, rank2=900, rank109=1, rank110=0) | ✅ |
| System① 回帰 | 2024-25(<2025-08-01)は旧値のまま(非JCX rank1=180, JCX rank1=200) | ✅ |
| System② AJOCC_267_TEST | グレード非依存で rank1=1000/rank2=900/rank109=1/rank110=null | ✅ |

---

## 結合・実データ検証

### 再計算バッチ（recalcSeason 16）
- 対象1170カテゴリ（リザルト有・有効分）を再スコアリング → `total=1170 ok=1170 skip=0 ng=0`。

### 再計算後のtier分布（season16 非JCX rank1, deleted=0）
| ajocc_pt | tier | カテゴリ数 |
|---|---|---|
| 400 | 100人以上 | 42 |
| 350 | 40-59 | 73 |
| 300 | 20-39 | 140 |
| 250 | 10-19 | 140 |
| 200 | 1-9 | 514 |

→ 実態（小規模カテゴリ多数）を反映。per-category出走人数が正しく機能。

### JCX大会（season16, deleted=0）
- rank1 = 1000（新JCX列）を確認。

### 回帰（season15=2024-25, 未操作, deleted=0）
- 非JCX rank1 = 180/150/100（旧3段階のまま）/ JCX rank1 = 200 → **不変を確認**。

---

## 実装中に発見・修正した不具合

| # | 不具合 | 原因 | 対処 |
|---|---|---|---|
| 1 | バッチ全件スキップ | クエリ結果キーの誤り(`$r[0]`→`$r['ec']`) | キー修正 |
| 2 | Flash nullで停止 | リザルト未登録カテゴリでWeb専用Flash呼び出し | EXISTSフィルタ＋try/catch |
| 3 | **ほぼ全カテゴリが最上位tier(400)** | コンポーネント使い回しで`__started`(出走人数)がカテゴリ跨ぎで累積 | **カテゴリ毎に新インスタンス生成**（本番と同挙動） |

> いずれもバッチ固有の問題で、本番コード（`reCalcResults`本体）は無変更・無影響。

---

## 重要な学び（データモデル）
- `racer_results.deleted` は論理削除フラグ。同一entry_racerに複数行あるのは過去の再計算履歴（論理削除済み）。`deleted=0`で有効行が一意に定まる。検証クエリは必ず `deleted=0` で絞ること。

---

## 成果物
- 現行/26-27 ランキングCSV: `outputs/baseline/`, `outputs/after_2627/`（AJOCC各29＋シリーズ各23）
- 比較サマリー: `comparison-summary.md`
