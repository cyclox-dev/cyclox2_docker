# Brief: jcx-lineage-lock-2026-27

## Problem

AJOCC 2026-27規則改正で、通常戦では同一シーズン内のエリート⇔マスターズの行き来が自由化される
一方、**JCXシリーズ戦では従来どおり系統固定**となる。対応ペア両保有モデル（me-mm-linkage-2026-27）
導入後は選手が常時両系統のカテゴリーを保有するため、JCX 大会において「シーズン内で系統を
固定する」制御をエントリー時に行わないと、規則違反のエントリーをシステムが許してしまう。

## Current State

- JCX 大会は大会属性（is_jcx 相当のフラグ）で識別できる（PointCalculator の JCX 表適用で使用実績）。
- エントリーの出走可否は EntryCatLimit（ELITE='e' / MASTERS='m' / NONE='n'、catGroupId 対応）等の
  仕組みでカテゴリー制限しているが、「同一シーズンの JCX 戦系統固定」という時系列制約は存在しない。
- 選手がシーズン内のどの JCX 戦にどの系統で出走したかは entry_racers / racer_results から追跡可能。

## Desired Outcome

- 選手が当該シーズンの JCX シリーズ戦に初めて出走した系統（エリート or マスターズ）が、
  同シーズンの以降の JCX 戦で固定される: 異なる系統での JCX エントリーが検出・防止
  （または警告）される。
- 通常戦のエントリーには影響しない（自由な行き来を妨げない）。
- 制御の強度（ハードエラー / 警告+管理者確認）は要件定義で確定する。

## Approach

エントリー登録・変更経路に「JCX 系統固定チェック」を追加する。判定は
me-mm-linkage-2026-27 の系統判定（カテゴリー→系統のマッピング）を参照し、
当該シーズン・当該選手の既存 JCX エントリー/出走の系統と突合する。
主催者向け一括エントリー経路（CSV 取込等があれば）も同じチェックを通す。

## Scope

- **In**:
  - JCX 大会の識別方法の確定（既存フラグの流用可否）
  - シーズン内 JCX 系統の初回確定と以降のエントリーチェック
  - エントリー全経路（画面・API・一括取込）への適用調査と実装
  - 単体テスト（TDD）
- **Out**:
  - 通常戦のエントリー制御変更
  - JCX シリーズ点計算（既存 calc_rule / point-sim の範囲）
  - カテゴリー保有そのものの制御（→ me-mm-linkage-2026-27）

## Boundary Candidates

- 系統判定（me-mm-linkage の共有 API） / JCX 固定状態の算出（read） / エントリーチェック（write 経路）

## Out of Boundary

- res-sys（閲覧側）は対象外
- JCX 規則のその他の変更（本改正の告知にある範囲外）

## Upstream / Downstream

- **Upstream**: me-mm-linkage-2026-27（系統マッピング）、entry_racers / racer_results（出走実績）、
  大会の JCX フラグ
- **Downstream**: 2026-27 シーズンの JCX 大会運用

## Existing Spec Touchpoints

- **Extends**: なし（新規）
- **Adjacent**: me-mm-linkage-2026-27（系統判定を共有）、point-sim-2025-26（is_jcx の扱いを参照）

## Constraints

- エントリー業務（大会前の繁忙期処理）を止めないこと。パフォーマンス影響最小
- 制御強度（エラー/警告）は主催者運用と整合させる（要件定義で人間に確認）
- 期限 2026-07-31
