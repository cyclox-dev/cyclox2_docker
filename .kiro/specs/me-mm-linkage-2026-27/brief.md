# Brief: me-mm-linkage-2026-27

## Problem

AJOCC 2026-27規則改正により、実力別エリート（ME1〜ME4）と実力別マスターズ（MM1〜MM3）が実質統合され、
系統間の行き来が自由化・昇格が連動する。現行 cyclox2 は両系統を完全に別個管理しており、
(1) 昇格が片系統内で完結し連動しない、(2) 主催者が切替画面（change_em）を使わず新カテゴリーを
追加付与するだけのケースが多く、旧系統の所属が生き残って「MM1とME4の二重付与」のような不整合が
発生・放置され、シーズン毎の降格処理で不整合が拡大し続けている。

## Current State

- 認定カテゴリーは `category_racers`（racer_code / category_code / apply_date / cancel_date / reason_id）。
  複数カテゴリー同時有効保有を防ぐ制約は DB にもアプリにもない。
- リアルタイム昇格は `app/Controller/Component/ResultParamCalcComponent.php`（1勝昇格・2勝昇格・
  順位昇格 → `__execApplyRankUp()` が新 CategoryRacer 追加＋HoldPoint 3pt 付与）。単一系統内で完結。
- E⇔M 切替は `CategoryRacersController::change_em()`（対応表 CM1→C2, C1→CM1 等を内包。
  旧側 cancel_date=8/31、新側 apply_date=9/1、reason_id=REQUEST_CHANGE(11)）。
- カテゴリーコード: ME1〜ME4=C1〜C4、MM1〜MM3=CM1〜CM3（categories テーブル、PK=code）。
- 両保有モデルとの適合性検証済み（2026-07-14 実施。反証志向のコード調査）:
  - **適合**: 昇格判定（同系統内で完結・OR判定）、AJOCCランキング集計（category_code 毎に独立、
    両系統出走者は両方に正しく計上される設計）、API・ビュー表示（全件 foreach、
    `find('first')` で単一現カテゴリー扱いする箇所なし）、res-sys 側（複数保有前提の実装）
  - **要改修（高）**: `CatLimitShell::setupCatLimit()` — シーズン毎に e/m 排他1文字を
    `Racer.cat_limit` に記録する cron バッチ。両系統出走者で誤情報になる（表示用途のみだが要対処）
  - **要改修（高）**: `change_em` — 乗換時に反対系統を丸ごと cancel する設計。両保有の正当な
    保有を破壊しうる。内包する対応マップ（C3→CM3 等）は新ルールの対応ペアと異なる点にも注意
  - **要改修（中）**: CategoryRacer モデルに重複禁止バリデーションが皆無（同一カテゴリー重複も
    現状防げていない）。`OrgUtilController::unite_racer`（選手統合）も重複チェックなし
  - category_racers への書込全経路は 14 経路を列挙済み（設計時に検証レポート参照）

## Desired Outcome

- 選手が対応ペア（C2+CM1 / C3+CM2 / C4+CM3、C1 は CM1 と※条件付き）を両方有効保有する状態を
  正常系として扱える。
- どちらの系統のレースで昇格しても、両系統の認定カテゴリーが対応表に沿って連動更新される
  （例: ME3 昇格 → C3/CM2 を終了し C2/CM1 を付与）。
- ME1 特例: ME2→ME1 昇格時 MM 側は MM1 のまま。MM1→ME1 への移行は「元ME1」の選手に限る
  （元ME1 判定は category_racers 履歴から導出）。
- 対応外ペア（例: CM1 と C4 の同時有効保有）を作る保存操作はバリデーションエラーで弾かれる
  （自動整合はしない。2026-07-14 合意）。
- 通常戦での系統間の行き来が両保有によって自然に可能（シーズン内切替の運用が不要になる）。
  change_em 画面の位置づけ（ペア補完ツール化 or 廃止）が決まり実装される。

## Approach

案A「対応ペア両保有モデル」（roadmap.md 参照）。ME⇔MM 対応表を単一の正として定義し
（他 spec からも参照）、昇格処理・バリデーション・切替画面をその対応表ベースで改修する。
既存 `category_racers` の履歴構造は変更しない。

## Scope

- **In**:
  - ME⇔MM 対応表の定義（単一ソース。女子系統の対応要否は要件定義で確認）
  - リアルタイム昇格の連動（ResultParamCalcComponent、HoldPoint の付与先の扱い決定を含む）
  - category_racers 保存全経路への対応外ペア禁止バリデーション（エラーで弾く）
  - change_em の改修（新ルール下での役割再定義。反対系統一括 cancel の廃止/保護を含む）
  - `CatLimitShell::setupCatLimit()` の両系統対応（e/m 排他前提の cat_limit 記録の見直し）
  - 選手統合（unite_racer）への重複チェック追加、同一カテゴリー重複禁止バリデーション
  - 元ME1 判定ロジック
  - 上記の単体テスト（TDD）
- **Out**:
  - 既存不整合データの是正（→ catracer-cleanup-2026-27）
  - シーズン末の残留・降格判定ルール（→ season-rules-2026-27）
  - JCX 大会でのエントリー制御（→ jcx-lineage-lock-2026-27）
  - ポイント表（→ ajocc-point-267-prod）

## Boundary Candidates

- 対応表定義（Const/Util 層） / 昇格連動（Component 層） / バリデーション（Model 層） /
  画面（Controller/View 層）という層別の切り分け
- 「ペア判定・対応表参照 API」を独立モジュールにし、他 spec の依存点を1箇所に集約

## Out of Boundary

- 過去データの書き換え・是正（本 spec は今後のデータを正しく保つ仕組みのみ）
- ランキング集計ロジック自体の変更（両保有選手が両系統ランキングに載ることの検証は設計時に確認）

## Upstream / Downstream

- **Upstream**: category_racers / categories / hold_points の既存構造、
  ResultParamCalcComponent の既存昇格ロジック
- **Downstream**: catracer-cleanup-2026-27（対応表・合法状態の定義を参照）、
  season-rules-2026-27（系統横断残留判定）、jcx-lineage-lock-2026-27（系統判定）

## Existing Spec Touchpoints

- **Extends**: なし（新規）
- **Adjacent**: rider-demotion-2025-26（category_racers の更新パターン・reason_id 運用を踏襲）、
  point-sim-2025-26（ResultParamCalcComponent を共有）

## Constraints

- CakePHP 2.x / PHP 7.3 / MySQL 5.7。DB スキーマ変更は最小限（原則なし。必要なら設計で協議）
- 期限 2026-07-31。TDD。二重付与防止は「エラーで弾く」方式（2026-07-14 合意）
- 両保有モデルが既存コード（エントリー制限・ランキング集計・res-sys 表示）を壊さないことの
  検証結果（validate-gap）を設計に反映すること
