# Brief: catracer-cleanup-2026-27

## Problem

主催者が E⇔M 切替画面を使わず相当カテゴリーを新規付与するだけの運用が常態化した結果
（関西以外でほぼ）、旧系統の所属が有効なまま残り、シーズン毎の降格処理で独立に降格し続けて
「MM1 と ME4 の同時保有」のような対応外ペア保持選手が多数存在する。新ルール（対応ペア両保有
モデル）の導入前提として、既存データを正しい対応ペアに是正する必要がある。

## Current State

- `category_racers` に同一選手の対応外カテゴリーが複数、`cancel_date=NULL` のまま並存。
- 類似バッチの先例: `OneTimeShell::setupDuplicatedCatRacerDeleted()`（完全重複の削除）、
  rider-demotion-2025-26 の検出→downlist→SQL生成→検証フロー（`docs/specs/rider-demotion-2025-26/`）。
- どの選手がどれだけ不整合かの全体像は未集計。

## Desired Outcome

- 不整合（me-mm-linkage-2026-27 の対応表に照らして違法な有効保有の組合せ）の選手を全件検出できる。
- 「直近の出走実態」基準（2026-07-14 合意）で正カテゴリーを決定し、旧側を cancel_date で終了・
  必要な対応ペアを付与する是正が一括実行できる。
- バッチは**任意のタイミングで繰り返し実行可能**（冪等）。dry-run（logonly）モードを持ち、
  実行結果はレポートとして出力・記録される。
- 是正後の全データが me-mm-linkage-2026-27 のバリデーションを通る（違法ペアゼロ）。

## Approach

CakePHP Console シェルとして実装（任意タイミング実行・冪等・logonly 対応）。
判定は「直近の出走実態」= 対象選手の直近レース出走（racer_results / entry_racers）がどの系統の
races_category だったかを基準に、その系統の現保有カテゴリーを正とし、対応表から他系統のペアを
確定する。履歴は削除せず cancel_date + reason_id/reason_note で終了記録を残す
（rider-demotion-2025-26 の更新パターン踏襲）。

## Scope

- **In**:
  - 不整合検出クエリ／レポート出力（件数・選手・保有状況・判定根拠）
  - 直近出走実態に基づく正カテゴリー決定ロジック（出走実績が無い等のエッジケースの扱い含む）
  - 是正実行（TRANSACTION、logonly モード、冪等性、実行ログ）
  - ローカルダンプでの実行検証と test-results 記録
  - 単体テスト（TDD）
- **Out**:
  - 対応表・合法状態の定義（me-mm-linkage-2026-27 が正）
  - 将来の再発防止（同 spec のバリデーション）
  - シーズン末降格の判定変更（season-rules-2026-27）
  - 本番への適用作業そのもの（検証済み手順の提供まで。実行は人間）

## Boundary Candidates

- 検出（read-only）と是正（write）の分離 — 検出のみ先行リリース・実行可能にする
- 判定ロジック（純粋関数）と DB 更新の分離（テスト容易性）

## Out of Boundary

- 対応外ペア以外のデータ不整合（完全重複レコード等）の是正は対象外
  （必要なら既存 setupDuplicatedCatRacerDeleted を案内）

## Upstream / Downstream

- **Upstream**: me-mm-linkage-2026-27（対応表・違法ペア定義）、racer_results / entry_racers（出走実態）、
  rider-demotion-2025-26 の SQL 資産・更新パターン
- **Downstream**: 2026-27 シーズン運用（是正後データが前提）、season-rules-2026-27 のシーズン末処理

## Existing Spec Touchpoints

- **Extends**: なし（新規）
- **Adjacent**: rider-demotion-2025-26（category_racers 更新の作法・検証フローを踏襲）

## Constraints

- 是正基準は「直近の出走実態」、実行タイミングは任意（2026-07-14 合意）
- 履歴保全: 物理削除しない。cancel_date + reason 記録で終了
- 本番適用は人間が判断・実行（A案: 検証済み SQL/コマンドの適用）
- 期限 2026-07-31（ローカル検証完了まで）
