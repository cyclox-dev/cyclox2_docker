# Brief: season-rules-2026-27

## Problem

AJOCC 2026-27規則改正により、昇格・残留・降格のルール値と判定方法が変わる:
(1) MM2→MM1 の昇格上限が最大2名→最大3名、(2) ME2 残留基準 260位→240位・ME3 280位→240位、
(3) WE1 に残留基準を新設（80位以上）、(4) 残留判定が系統横断化（ME/MM どちらか一方で基準を
満たせば残留。ME1 のみ ME1 成績だけで判定。降格は対応表に沿って両系統連動）。
現行のリアルタイム昇格ロジックとシーズン末降格処理（runbook/SQL）は旧ルール前提。

## Current State

- リアルタイム昇格の人数枠: `ResultParamCalcComponent` 内の出走人数別ルール
  （40人以上=上位3名、20人以上=2名、10人以上=1名 等）。MM2→MM1 の上限は現行2名。
- シーズン末降格: `.kiro/specs/rider-demotion-2025-26/runbook.md` + `sql/` 資産
  （2025-26 実績: ME 240/260/280位、MM 80/40点、WE1 出走判定。カテゴリー単位・系統独立に判定）。
- HoldPoint（昇格時 3pt）が残留判定の材料（一部カテゴリー）。
- WE1（CL1）は残留基準なし（出走のみで残留）だった。

## Desired Outcome

- 2026-27シーズンのリアルタイム昇格で MM2→MM1 が最大3名まで昇格できる。
- 2026-27シーズン末の残留・降格判定が新基準（ME2/ME3=240位、WE1=80位）かつ系統横断
  （どちらか満たせば残留、ME1 例外、降格は対応ペアで連動）で実行できる状態になっている:
  判定ロジック／SQL・runbook が改訂され、ローカルダンプで検証済み。
- 昇格枠・残留ラインの値がコード内に散在せず、シーズン毎に更新しやすい形で管理される。

## Approach

二層で対応する。(a) リアルタイム昇格枠（MM2→MM1=3名）は ResultParamCalcComponent の
ルール定義を 2026-27 シーズンから切り替え（既存の「〜16-17まで」ルール切替パターンを踏襲）。
(b) シーズン末処理は rider-demotion-2025-26 の runbook/SQL 資産を新ルール対応版に改訂し、
系統横断残留判定（me-mm-linkage-2026-27 の対応表を参照）を組み込む。実行は 2027-03 だが、
判定ロジックの実装・検証は本 spec で完了させる。

## Scope

- **In**:
  - MM2→MM1 昇格上限 3名への変更（2026-27 以降適用、過去シーズン非影響）
  - 残留ライン新値（ME2/ME3=240位、WE1=80位）の定義と管理方法の整理
  - 系統横断残留・連動降格の判定ロジック（SQL/バッチ）と runbook 改訂
  - ローカルダンプでの判定検証（2025-26 データでのシミュレーション）
  - 単体テスト（TDD）
- **Out**:
  - 2026-27 シーズン末降格の本番実行（2027-03、人間が runbook に従い実施）
  - 昇格連動の仕組みそのもの（→ me-mm-linkage-2026-27）
  - ポイント表（→ ajocc-point-267-prod）

## Boundary Candidates

- リアルタイム昇格枠（アプリコード）とシーズン末判定（runbook/SQL）の分離
- ルール値（残留ライン・昇格枠）の定義を1箇所に集約

## Out of Boundary

- 是正バッチ（catracer-cleanup-2026-27）。ただしシーズン末判定は是正済みデータを前提とする

## Upstream / Downstream

- **Upstream**: me-mm-linkage-2026-27（対応表・両保有モデル・HoldPoint 扱い）、
  rider-demotion-2025-26（runbook/SQL 資産）、ajocc-point-267-prod（順位算出の元となるポイント）
- **Downstream**: 2026-27 シーズン末の降格処理実行（2027-03）

## Existing Spec Touchpoints

- **Extends**: rider-demotion-2025-26 の runbook を次年度版に改訂（同 spec は完了済みのため
  新 spec として実施し、runbook の「次年度の更新点」方式を活用）
- **Adjacent**: me-mm-linkage-2026-27（ResultParamCalcComponent を共有。変更競合に注意）

## Constraints

- 過去シーズンの昇格・降格結果に影響しないこと（シーズン起点でのルール切替）
- WE1 の集計は races_category_code IN ('CL1','UCIWE')（UCIWE 漏れの既知の落とし穴に注意）
- 期限 2026-07-31（判定ロジック・runbook 改訂・検証完了まで）
