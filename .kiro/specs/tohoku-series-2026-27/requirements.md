# 要件定義: tohoku-series-2026-27

タスクID: `tohoku-series-2026-27`
作成日: 2026-08-15

## Project Description (Input)

cyclox2 には、独自ランキングを実現するためのポイントシリーズグループ機能があり、シリーズごとに
使用するポイントテーブル（`point_series.calc_rule` で選択される計算器）を実装することで
ランキングを成立させている。2026-27シーズンについて東北シリーズを新たに作成することが決まった
（東北シリーズは 2017-18 シーズン以降、継続的にポイントシリーズを実装している）。使用する配点は
2026-27シーズン向けに改正された新AJOCC得点表である。過去シーズン（`TCX_223` / `TCX_245`）と
同じ方式で、`PointCalculator` に東北シリーズ用の計算器を追加する。

## Introduction

本仕様は、2026-27シーズンの東北シリーズ（東北シクロクロス）のランキング集計に使用する
ポイント計算器 `TCX_267`（`calc_rule=14`）を `app/Cyclox/Util/PointCalculator.php` に追加する。
配点は 2026-27 新AJOCC得点表の **出走人数8区分表**（AJOCCポイント列）をそのまま使用し、
**JCX列は使用しない**。これは `TCX_223`（22-23）・`TCX_245`（24-25）が「その年度の AJOCC
ポイント表をそのまま流用し、JCXテーブルは使わない」という方針で実装されてきたことの踏襲である。

本仕様の変更は `PointCalculator.php` 1ファイルとその単体テストに閉じる。東北シリーズ本体
（`point_series` レコード）および大会紐付け（`meet_point_series`）の登録は管理画面上の
データ作業であり、コード変更を伴わない。本仕様では runbook として手順のみを残し、実施は
リリース後に運用担当者が行う。

本仕様の成果物は `ajocc-point-267-prod`（新AJOCC得点表の本番化）と **同一リリースで本番反映**
することが決まっている。両者は `release/2026-27-season-rules` ブランチに集約し、`main` への
先行リリースとして出す。

## Boundary Context

- **In scope**:
  - `PointCalculator` への `TCX_267`（`val=14`）の追加（テーブル定義・計算器登録・`calc()` の
    分岐追加・管理画面表示用の説明テキスト生成）
  - 上記に対する単体テスト（TDD）の整備
  - `TCX_267` の数値が 2026-27 新AJOCC得点表（非JCX・8区分）と一致することの検証
  - 既存計算器（特に `AJOCC_267`=13, `TCX_245`=12）の計算結果が変化しないことの回帰確認
  - 2026-27東北シリーズの `point_series` / `meet_point_series` 登録手順の runbook 化
  - `ajocc-point-267-prod` の未消化結合試験項目を含めた、先行リリース前の結合試験実施
- **Out of scope**:
  - 2026-27東北シリーズの `point_series` / `meet_point_series` レコードの実登録
    （リリース後に運用担当者が管理画面で実施する。本仕様は手順のみ提供）
  - 東北シリーズのカテゴリー構成・シリーズ本数の決定（大会運営の中で主催者が決定する事項であり、
    `TCX_267` はカテゴリー非依存のためコードには影響しない）
  - `point_series_groups` の新規作成（「東北」グループ `id=2` は既存）
  - `seasons` の新規作成（2026-27 `id=17` は既存）
  - AJOCCポイント（System①、`racer_results.ajocc_pt`）の計算ロジック
    （`ajocc-point-267-prod` の対象。本仕様は同一の得点表数値を参照するのみで変更しない）
  - `AJOCC_267`（`val=13`）の定義・挙動の変更
  - 集計方式（`sum_up_rule` / `point_term_rule` / `point_to`）の新規実装・変更
    （既存値をそのまま踏襲する）
- **Adjacent expectations**:
  - `ajocc-point-267-prod` が `PointCalculator` に `AJOCC_267`（`val=13`）を確定させている。
    本仕様はその直後の採番 `val=14` を使用する
  - オープン中の `me-mm-linkage-2026-27`（PR #13）・`jcx-lineage-lock-2026-27`（PR #15）は
    いずれも `PointCalculator.php` を変更していないため、`val=14` の採番衝突は発生しない
  - 成績閲覧アプリ（`cyclox2ressys_svr/cyclox2res_sys`）は既存のシリーズランキング表示経路を
    そのまま利用するため画面変更は想定しないが、表示互換性は結合試験で確認する

## Requirements

### Requirement 1: 東北シリーズ用ポイント計算器 `TCX_267` の提供

**Objective:** As a AJOCC運営担当者, I want 2026-27東北シリーズのシリーズランキングを新AJOCC
得点表で集計できるポイントテーブルを管理画面から選択できること, so that 2026-27シーズンの東北
シリーズを改正後の配点で正しく運用できる。

#### Acceptance Criteria

1. The `PointCalculator` shall `TCX_267` を `val=14`、`name='TCX_267'` として定義し、
   `calculators` レジストリに登録する。
2. When `PointCalculator::getCalculator(14)` が呼ばれた時, the システム shall `TCX_267` の
   計算器インスタンスを返す。
3. When `point_series.calc_rule=14` のシリーズでポイント計算が実行された時, the システム shall
   `TCX_267` のテーブルに基づくポイントを返す。
4. The `PointCalculator` shall `TCX_267` の `description` / `text` に、2026-27 東北クロス用で
   あること・AJOCCポイントと同配点であること・JCXテーブルを使用しないこと・ボーナスがないこと・
   グレード指定が不要であることを日本語で明示する。
5. The `TCX_267` の `text` shall 全8区分のポイントテーブルを、区分ごとに `---` 区切り・
   「N人以上」見出し・10件区切りの配点列という書式で出力する。**かつ各区分の末尾で必ず改行する**
   （8区分の要素数 119/99/79/59/39/19/9/4 はいずれも10の倍数ではないため、10件区切りのみでは
   区分末尾が改行されず次区分の `---` が同一行へ連結して表示が崩れる。既存計算器では
   `KNT_178` がこの改行補正を持つ書式であり、`TCX_223` / `TCX_245` は持たない。本仕様は
   `KNT_178` の書式に従う）。
6. Where 管理画面の配点ルール選択（`PointSeries/add`・`PointSeries/edit`）が表示される場合,
   the システム shall 選択肢に `TCX_267` を表示する。

### Requirement 2: 2026-27 新AJOCC得点表（8区分・非JCX）の正確な実装

**Objective:** As a AJOCC運営担当者, I want `TCX_267` の配点が新AJOCC得点表と完全に一致すること,
so that 東北シリーズのランキングが公式配点と齟齬なく算出される。

#### Acceptance Criteria

1. The `TCX_267` shall 出走人数による8区分（100人以上／80人以上／60人以上／40人以上／20人以上／
   10人以上／5人以上／それ未満）を持ち、既存 `TCX_223` / `TCX_245` と同じ
   `__KEY_STARTED_OVER`（それぞれ 99 / 79 / 59 / 39 / 19 / 9 / 4 / 0）方式で表現する。
2. The `TCX_267` の各区分の配点列 shall `ResultParamCalcComponent::__getAjoccPointMap()` が
   2026-09-01以降・非JCXの大会に対して使用する配点列と、区分・順位ともに完全に一致する。
3. When 出走人数が区分境界値（4/5、9/10、19/20、39/40、59/60、79/80、99/100）である時,
   the システム shall 上位区分・下位区分のうち正しい方の配点を適用する。
4. The `TCX_267` shall JCX列（`AJOCC_267` が使用する1000点始まりの表）を使用しない。
5. The `TCX_267` shall ボーナスポイントを付与しない（返却値に `bonus` を含めない）。
6. The `TCX_267` shall グレード（`$grade`）の値によって配点を変えない。

### Requirement 3: 順位・範囲外の扱い

**Objective:** As a 開発・保守担当者, I want 順位が無い場合や表範囲外の順位に対する挙動が既存の
東北シリーズ計算器と同一であること, so that シリーズ集計の例外挙動が過去シーズンと一貫する。

#### Acceptance Criteria

1. If リザルトに順位（`rank`）が無い（空）場合, then the `PointCalculator::calc()` shall `null` を返す。
2. When 順位が該当区分の配点列の範囲外である時, the `PointCalculator::calc()` shall **`null` を返す**。
   内部計算（`__calcTCX267()`）はポイント `0` を返すが、`calc()` 末尾の
   `if (empty($pt['point']) && empty($pt['bonus'])) return null;` により外部からは `null` として
   観測される。これは既存 `TCX_245` / `AJOCC_267` と同一の挙動である
   （既存テスト `testAjocc267Rank110ReturnsNull` が実証）。
3. When 順位が該当区分の配点列の最終要素に一致する時, the `PointCalculator::calc()` shall
   その要素の値をポイントとして返す。
4. While `calc()` が `null` を返す場合, the `ResultParamCalcComponent::__resetSeriesPoints()` shall
   当該選手の `point_series_racers` 行を作成しない（`if (!empty($pt))` により分岐）。すなわち
   「順位なし」と「表範囲外」は外部から区別できず、いずれも0点行ではなく行の不存在となる。
   これは既存計算器と同一の集計挙動であり、本仕様で変更しない。

### Requirement 4: 既存計算器への非回帰

**Objective:** As a 開発・保守担当者, I want 本改修が既存のポイント計算に一切影響しないこと,
so that 過去シーズンおよび他シリーズのランキングが変化しない。

#### Acceptance Criteria

1. The システム shall `AJOCC_267`（`val=13`）の計算結果を本改修前と同一に保つ。
2. The システム shall `TCX_245`（`val=12`）の計算結果を本改修前と同一に保つ。
3. The システム shall 既存の全計算器（`val=1`〜`13`）の `val` / `name` を変更しない。
4. The システム shall `ResultParamCalcComponent`（System①、AJOCCポイント計算）に変更を加えない。
5. The システム shall DBスキーマを変更しない。

### Requirement 5: シリーズ登録手順の runbook 化

**Objective:** As a AJOCC運営担当者, I want リリース後に自分で2026-27東北シリーズを登録できる
手順書があること, so that コード変更を待たずにシリーズ設定を完了できる。

#### Acceptance Criteria

1. The runbook shall `point_series` 登録時の設定値として `calc_rule=14`、`sum_up_rule=2`
   （全戦合計のみ）、`point_term_rule=1`（無期限有効）、`point_to=1`（選手へ付与）、
   `season_id=17`（2026-27）、`point_series_group_id=2`（東北）を明記する。
2. The runbook shall シリーズ名・略称の命名規則（`東北シクロクロス26-27{カテゴリー}` /
   `TCX26-27{カテゴリー}`）を明記する。
3. The runbook shall シリーズ本数・カテゴリー構成が主催者判断で決まるため固定しないこと、および
   25-26 実績（12本）を参考情報として併記する。
4. The runbook shall `publishes_on_ressys` / `publishes_newest_asap` の設定について、25-26 実績
   （上位カテゴリー6本が `1`、他が `0`）を参考情報として併記する。
5. The runbook shall シリーズ登録後に `meet_point_series` で対象大会・エントリーカテゴリーを
   紐付ける必要があること、およびその前提として 2026-27 シーズンの大会（`meets`）が登録済みで
   ある必要があることを明記する。
6. The runbook shall `meet_point_series` の必須項目（`express_in_series`（NOT NULL、25-26 実績は
   `#1亘理` 形式）、`meet_code`、`entry_category_name`）を明記する。
7. The runbook shall **紐付けはリザルト登録前（シーズン開幕前）に完了させる**こと、および既に
   リザルトが登録済みの大会へ後から紐付けた場合は **対象エントリーカテゴリーのリザルト再計算
   （`reCalcResults`）を実行しないと `point_series_racers` が生成されず、シリーズランキングが
   空のままになる**ことを明記する。
8. The runbook shall 本番DBに `calc_rule=13`（`AJOCC_267`）を使用する既存 `point_series` 行が
   存在しないことの確認手順を含める（開発環境では0件を確認済み）。
9. The runbook shall 記載値が開発環境DBの調査結果に基づくものであり、実施時に本番環境で確認する
   よう注意喚起する。

### Requirement 6: `ajocc-point-267-prod` との同時リリース

**Objective:** As a AJOCC運営担当者, I want 新AJOCC得点表の本番化と東北シリーズ対応が同じ
リリースで本番反映されること, so that 2026-27シーズン開幕（2026-09-01）前に必要な変更が
一括で有効になる。

#### Acceptance Criteria

1. The 実装ブランチ shall **`origin/release/2026-27-season-rules`** を起点とし、同ブランチへ
   PR を出す。ローカルの `release/2026-27-season-rules` は `origin/main` と同一の古い状態で
   あるため、起点にしてはならない（調査で確認。詳細は design.md「起点ブランチの注意」参照）。
2. The システム shall `release/2026-27-season-rules` → `main` の先行リリースに、
   `ajocc-point-267-prod` の変更と本仕様の変更の両方を含める。
3. Before 先行リリース, the 担当者 shall `ajocc-point-267-prod` の未消化の結合試験項目（17項目）と
   本仕様の結合試験項目の両方を **実施し**、結果を `test-results.md` および各
   `integration-test-checklist.md` に記録する。
4. Before 結合試験, the 担当者 shall 親リポジトリ `cyclox2_docker` の submodule を
   リリース対象のコミット（release + 本仕様のマージ結果）へチェックアウトする。
   親リポジトリ `main` の submodule ポインタは現在 `feat/jcx-lineage-lock-2026-27` の
   未マージコミットを指しているため、これを行わないとリリース対象でないビルドを検証してしまう。
5. The 先行リリース shall `--no-ff`（マージコミットを残す方式）で行う。squash / rebase を選ぶと
   `release/2026-27-season-rules` 再利用時に履歴が乖離し、後続の `main` → `release` 追随マージで
   二重適用・コンフリクトを招く。
6. The 先行リリース shall 2026-09-01（2026-27シーズン開幕）より前に完了する。
