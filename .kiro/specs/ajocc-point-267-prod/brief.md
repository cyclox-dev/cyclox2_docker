# Brief: ajocc-point-267-prod

## Problem

AJOCC 2026-27規則改正でポイント表が全面改正され、出走人数区分が3種類から8種類
（1-4/5-9/10-19/20-39/40-59/60-79/80-99/100+）に細分化された。cyclox2 には新表が
`AJOCC_267_TEST` としてシミュレーション用に実装済み（point-sim-2025-26）だが、
本番の AJOCC ポイント計算には適用されていない。2026-27シーズン開幕までに本番化が必要。

## Current State

- `app/Cyclox/Util/PointCalculator.php` に AJOCC_267_TEST（ID=13、8区分・109位まで・
  グレード分け無し）が定義済み。
- 適用は `ResultParamCalcComponent::enableSimAjocc267()` フラグ経由のシミュレーション
  モードのみ（point-sim-2025-26 で 2025-26 全レースの再計算・CSV 比較検証済み）。
- `PointSimShell` がシミュレーション実行の入口。
- submodule cyclox2web の作業ブランチ `feat/point-table-ajocc-267-sim` に関連コードがある
  （main へのマージ状況は要確認）。

## Desired Outcome

- 2026-27シーズン（開始日以降）の大会の AJOCC ポイント計算に新8区分表が自動適用される。
- 過去シーズン（2025-26 以前）の計算結果・再計算経路は従来表のまま影響を受けない。
- シミュレーション用フラグ（enableSimAjocc267 / _TEST 名称）による分岐が本番構成として
  整理される（フラグ恒久化 or シーズン起点の表切替として実装）。
- JCX 大会（is_jcx=1）への新 JCX 列適用も本番経路で機能する。

## Approach

既存の point-sim-2025-26 成果を昇格する。表データ自体は検証済みのため、主作業は
「適用条件の本番化」: シーズン／大会日付による表選択ロジックへの組み込み、TEST 名称の整理、
既存シーズンの非影響保証（回帰テスト）。適用開始日の決定（2026-27シーズン開始日）は
要件定義で確定する。

## Scope

- **In**:
  - AJOCC_267 の本番適用ロジック（適用開始シーズン/日付の判定）
  - シミュレーション専用フラグ・命名の整理
  - 過去シーズン非影響の回帰テスト（2025-26 の計算結果が変わらないこと）
  - 公式ポイント表 PDF（/2026/2026-2027ajoccpointtable.pdf）との数値照合
  - 単体テスト（TDD）
- **Out**:
  - シリーズ点計算（calc_rule）の新規変更（point-sim-2025-26 で定義済みの範囲を超える変更）
  - ポイント表管理の UI 化・DB 化などの構造改善
  - 残留ライン等のルール値（→ season-rules-2026-27）

## Boundary Candidates

- 表定義（PointCalculator） / 適用判定（ResultParamCalcComponent） / バッチ再計算（Shell）の分離

## Out of Boundary

- ME⇔MM 連動・カテゴリー管理には触れない

## Upstream / Downstream

- **Upstream**: point-sim-2025-26（表定義・検証結果）、submodule ブランチ
  feat/point-table-ajocc-267-sim のマージ状況
- **Downstream**: 2026-27 シーズンの全ポイント計算、AJOCC ランキング（tmp_ajoccpt_racer_sets）、
  season-rules-2026-27 の残留判定（ポイント基準カテゴリー）

## Existing Spec Touchpoints

- **Extends**: point-sim-2025-26 の成果を本番昇格（同 spec は完了済みのため新 spec として実施）
- **Adjacent**: me-mm-linkage-2026-27（ResultParamCalcComponent を共有。変更の競合に注意）

## Constraints

- 過去シーズンの計算結果を変えないこと（point-sim-2025-26 R1.4 の本番版）
- 公式 PDF の数値と完全一致すること
- 期限 2026-07-31
