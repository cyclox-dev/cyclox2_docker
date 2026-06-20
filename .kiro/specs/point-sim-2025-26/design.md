# 設計: 2025-26 新ポイントテーブル ランキングシミュレーション

タスクID: `point-sim-2025-26`
作成日: 2026-06-14

## アーキテクチャ概要

ポイントは2系統が独立。両方に新JCX列／新表を適用する。

```mermaid
flowchart TD
    SS[スプレッドシート<br/>AJOCC得点表 2026-27] -->|8区分列| S1A[System① 非JCX表]
    SS -->|JCX列| S1B[System① JCX大会表]
    SS -->|JCX列| S2[System② JCX/JCFシリーズ表]

    subgraph System① ajocc_pt
      S1A --> GMAP[__getAjoccPointMap]
      S1B --> GMAP
      GMAP --> AJPT[(ajocc_pt per result)]
      AJPT --> AJRANK[AJOCCランキングCSV<br/>download_ajocc_pt_csv]
    end

    subgraph System② シリーズ点
      S2 --> PC[PointCalculator AJOCC_267_TEST val=13]
      PC --> PSR[(point_series_racers)]
      PSR --> PSRANK[シリーズランキングCSV<br/>calcup / download_point_ranking_csv]
    end

    RECALC[OneTimeShell::recalcSeason 16] --> GMAP
    RECALC --> PC
```

## 変更点一覧

### 変更1: System① AJOCCポイント表（`ResultParamCalcComponent::__getAjoccPointMap`）

**方針**: 日付分岐を追加し、2025-26（`>= 2025-08-01`）に新表を適用。他シーズンは不変。

- `$divDate2025 = new DateTime('2025-08-01')` を追加。
- 最上位に新分岐を追加:
  - **非JCX**: 出走人数8区分の `mapArray`（`started_over` を 99/79/59/39/19/9/4/0 の降順で定義、各 `points` はスプレッドシート該当列、`defaultPoint=0`）。
  - **JCX (`$isJcx`)**: 単一表 `points` = 新JCX列（1000…）、`defaultPoint=0`。
- 既存の `>= $divDate2022` JCX分岐の選択ロジック（`$mapArray['points']`）と整合させるため、JCX時の戻り値構造を踏襲。

**注意（キャッシュ汚染）**: `calcAjoccPt` は `$this->ajoccPtMap` / `$this->defaultPt` を初回計算後キャッシュし、以降のリザルトで再利用する。Webの`recalc_result`はリクエスト毎にコンポーネント新規生成のため問題ないが、**バッチで1インスタンスを使い回すとカテゴリ跨ぎでキャッシュが誤再利用される**。→ バッチは出走カテゴリーごとにキャッシュを破棄（`unset`）または新規インスタンス化する（変更3で対応）。

### 変更2: System② シリーズ表（`PointCalculator`）

**方針**: 既存JCX_245を変更せず、新計算器 `AJOCC_267_TEST`(val=13) を追加。2025-26のJCF/JCXシリーズを新計算器へ付け替え。

- `public static $AJOCC_267_TEST;` を追加。
- `private static $TABLE_AJOCC267TEST = array(...)` = 新JCX列（順位1から、120位まで）。
- `init()` 内で `self::$AJOCC_267_TEST = new PointCalculator(13, 'AJOCC_267_TEST', '2025-26テスト用 JCF/JCXシリーズ新ポイント表（グレード区別なし）。', $text);` を生成し、`$calculators` 配列へ追加。
- `calc()` の switch に `case self::$AJOCC_267_TEST->val(): $pt = $this->__calcAJOCC267Test($result, $grade, ...); break;` を追加。
- `__calcAJOCC267Test()`: 順位ベースで単一表を引く。**グレード分岐なし**。表範囲外は0。
- **DB変更**: 2025-26の `calc_rule=11` シリーズ（実測**23件**）を `calc_rule=13` へ更新（SQL、`season_id=16`限定）。他シーズンのJCX_245利用シリーズは不変。

### 変更3: 再計算バッチ（`OneTimeShell::recalcSeason`）

- 引数: `seasonId`（=16）。
- 処理:
  1. 対象シーズンの全 `entry_categories`（meets→entry_groups→entry_categories, deleted=0）を取得（1,192件）。
  2. 各 ecatId につき:
     - `$this->ResultParamCalc` の AJOCCポイントマップキャッシュを破棄（`ajoccPtMap`/`defaultPt` を unset、または都度新規生成）。
     - `MeetPointSeries::setupTermOfSeriesPoint(meet_code, ecat_name)` を実行（シリーズ有効期間設定）。
     - `ResultParamCalc->reCalcResults(ecatId)` を実行（ajocc_pt と シリーズ点を再計算）。
  3. 進捗・失敗をログ出力。冪等。
- 実行: `docker-compose exec cyclox2_svr bash -c "cd /var/www/html/app && Console/cake OneTime recalcSeason 16"`

### 変更4: ランキングCSV出力（既存機構の再利用）

- **AJOCCランキング**: `OrgUtilController::download_ajocc_pt_csv`（`calcAjoccPoints` 利用）と同形式。カテゴリ別。
- **シリーズランキング**: `PointSeriesController::calcUpSeries` を直接呼ぶシェルで同形式CSVを生成。対象は 2025-26 JCF/JCXシリーズ（実測**23件**、calc_rule=13へ変更後）。
- バルク出力が必要なら、上記コントローラメソッドを呼ぶ薄いシェルを追加（任意）。

### 変更5: 本番フローからの隔離フラグ（`ResultParamCalcComponent`）※2026-06-20 追加

**背景**: 変更1の日付分岐（`>= 2025-08-01`）は**日付のみ**を条件にしており、本番の `reCalcResults`（Web の結果入力・編集）からも通る。PR #12 をこのままマージすると 2025-26 大会の再計算で**本番 `ajocc_pt` が 267_TEST 表で上書き**される（要件 R6 / R1.4 / R5.1 違反）。

**方針**: 日付分岐を**シミュレーション専用フラグ**でガードする。既定無効＝本番は従来どおり。

- `private $__simAjocc267 = false;`（既定=本番）を追加。
- `enableSimAjocc267()` / `disableSimAjocc267()` を追加（呼び出し時に `resetAjoccPtCache()` も実施しキャッシュ混在を防止）。
- `__getAjoccPointMap()` のガードを変更:
  ```php
  // before: if ($mtDate >= $divDate2025)
  // after:  if ($this->__simAjocc267 && $mtDate >= $divDate2025)
  ```
  → フラグ無効時は当該分岐を通らず、既存の年度別分岐へフォールバック（2025-08-01 以降も直近本番表＝PR導入前と同値）。
- `PointSimShell` 側で有効化（既存フローは無改修）:
  - `startup()` の検証用インスタンス、`recalcSeason()` のカテゴリ毎インスタンス生成直後に `enableSimAjocc267()` を呼ぶ。
- **本番化容易性（R6.4）**: 将来 267 を本番採用する際は、上記ガードから `$this->__simAjocc267 &&` を外す（=1条件削除）＋ `AJOCC_267_TEST` を正式名へリネームするだけでよい。テーブル本体・分岐配置は他年度テーブルと同一構造のまま。

## データフロー（再計算）

```
recalcSeason(16)
  └─ for each ecat (1,192):
       reset ajoccPtMap cache
       setupTermOfSeriesPoint()
       reCalcResults(ecatId)
         └─ __doReCalcResults()
              ├─ is_jcx 判定 → calcAjoccPt() → __getAjoccPointMap()  [System①: 新表]
              │    └─ ajocc_pt 保存
              └─ __reCalcResults() → __resetSeriesPoints()
                   └─ PointCalculator(calc_rule=13).calc()           [System②: 新表]
                        └─ point_series_racers 保存
```

## 影響範囲・リスク

| リスク | 対応 |
|---|---|
| バッチでのポイント表キャッシュ汚染 | カテゴリ毎にキャッシュ破棄（変更3） |
| 他シーズンへの波及 | System①は日付分岐(`>=2025-08-01`)、System②は新val=13＋season_id=16限定UPDATEで分離 |
| **本番フローへの 267_TEST 漏れ（日付分岐が本番 reCalcResults からも通る）** | **シミュレーション専用フラグでガード（変更5）。既定無効で本番は従来表。2026-06-20 対応** |
| `calc_rule=11→13` UPDATE の誤適用 | `season_id=16 AND calc_rule=11` で限定、件数(35)を事前確認 |
| 大量再計算の所要時間 | 1,192カテゴリー。ログで進捗確認、失敗は継続（not break）|
| 全日本(GRADE1)も新JCX列になる | 合意済み（決定#6: グレード区別廃止） |

## テスト方針（TDD）

詳細は test-results.md に記録。主な検証:
- **単体**: 新8区分表が出走人数で正しい列を返す（境界: 4/5, 9/10, 19/20, 39/40, 59/60, 79/80, 99/100）。
- **単体**: 新JCX列が順位で正しい値を返す（1位=1000, 109位=1, 110位=0）。
- **単体**: `__calcAJOCC267Test` がグレード非依存で同値を返す。
- **結合**: 既知の1カテゴリーを再計算し、手計算値と一致。
- **回帰**: 2024-25の代表カテゴリーの ajocc_pt が再計算後も不変。

---

## 実装結果・設計差分（2026-06-15 反映）

実装時に当初設計から変更・補強した点:

| 項目 | 当初設計 | 実装結果 |
|---|---|---|
| バッチ配置 | `OneTimeShell::recalcSeason` | 専用 `PointSimShell`（recalcSeason / testTables / exportSeries / exportAjocc / recalcOne）に集約 |
| 出走人数の状態管理 | カテゴリ毎にポイント表キャッシュ破棄で対応 | **キャッシュ破棄だけでは不十分**。`__started/__finished/__topLapCount` がインスタンス使い回しで累積するため、**カテゴリ毎に `ResultParamCalcComponent` を新規生成**（本番のリクエスト毎生成と同挙動）して解決 |
| 再計算対象 | 1,192カテゴリー | リザルト未登録カテゴリは `reCalcResults` 内のFlash(Web専用)でコンソールが落ちるため除外。**実処理 1,170件** |
| `calc_rule=11→13` 対象件数 | 35（推定） | 実測 **23件**（JCF/JCX/関西） |
| シリーズCSV生成 | `calcup`→`download_point_ranking_csv` | コントローラ依存を避け `PointSeriesController::calcUpSeries` を直接呼ぶシェル(`exportSeries`)で同形式CSVを生成 |
| データモデルの注意点 | （未認識） | `racer_results.deleted` が論理削除フラグ。検証は必ず `deleted=0` で行う（過去の再計算履歴が重複行として残るため） |

## 追補（2026-06-20）: 本番フロー隔離フラグの後追い対応

PR #12 レビューで、変更1の日付分岐が**本番 `reCalcResults` からも通り、マージすると本番 `ajocc_pt` が 267_TEST で上書きされる**ことが判明（要件 R6 を追加）。対応として**変更5（シミュレーション専用フラグ）**を実施。

| 項目 | 当初（PR #12 初版） | 改修（2026-06-20） |
|---|---|---|
| 日付分岐の発火条件 | `$mtDate >= 2025-08-01` のみ（無条件） | `$this->__simAjocc267 && $mtDate >= 2025-08-01`（フラグ有効時のみ） |
| 本番デフォルト | 2025-26 大会で 267_TEST が適用される（不具合） | フラグ無効＝従来表（PR導入前と同値） |
| 有効化箇所 | なし | `PointSimShell`（startup / recalcSeason）でのみ `enableSimAjocc267()` |
| 検証 | — | 実コードハーネスで OFF=180/200・ON=350/1000・回帰不変を確認（test-results.md 参照） |

### 降格ライン分析（T10・追加）
- 残留基準は AJOCC公式規定（cyclocross.jp）に準拠。
- マスターズ=点数基準(MM1:80/MM2:40) → 新表の点数インフレで降格者激減（76→24 / 49→18）。**閾値再較正が必須**。
- エリート=順位基準(ME1:240他) → 降格人数は概ね一定、顔ぶれが変化（C1で各12名逆転）。
- 詳細は `docs/specs/point-sim-2025-26/comparison-summary.md` および PPT を参照。
