# 引き継ぎ: AJOCC 2026-27 ルール改正対応（cyclox2 改修）

作成: 2026-07-15（旧セッションからの引き継ぎ資料。実装完了後は roadmap.md へ吸収して本ファイルは削除可）

## 現在地（フェーズ）

**Phase 1（仕様策定）完了・Phase 2（実装）未着手。**
5 spec すべて requirements / design / tasks 作成済み・クロススペック整合レビュー済み・
人間の決定事項も全件確定済み（`ready_for_implementation: true`）。
全体方針・スケジュール・合意事項・レビュー結果は [roadmap.md](roadmap.md) が正本。

## 作業環境（重要）

- **spec 文書の所在**: git worktree `.claude/worktrees/lucid-noether-b05c4b/`、
  ブランチ `claude/cyclox2-refactoring-93de72`。**全 spec ファイルが未コミット（untracked）**。
  最初にコミット→push→PR を人間に提案すること（main 直接コミット禁止）。
- **実装の作業場所**（2026-07-15 ユーザー確定）: アプリ本体の改修は
  **メインリポジトリ側の submodule** `/Users/kyamady/workspace/cyclox2_docker/cyclox2_svr/cyclox2/`
  （cyclox-dev/cyclox2web）で行う。worktree 内の submodule は未チェックアウト（空）。
- **実装着手時の必須準備**: submodule で `git fetch` → 最新 `origin/main` を取得して新ブランチ作成。
  現ローカルは古い（PR #12 マージ前の状態が混在。`feat/point-table-ajocc-267-sim` は PR #12 で
  マージ済みと確認済み。AJOCC_267_TEST 等のシンボルは最新 main に存在する）。
- ローカル DB: docker コンテナ `cyclox2_mysql`（root パスワードは `.env` の `MYSQL_ROOT_PASSWORD`）。
  本番ダンプ復元手順は `.kiro/specs/rider-demotion-2025-26/runbook.md` 参照。

## 実装順序と次のアクション

1. （人間）spec 文書のコミット・push・PR
2. `/kiro-impl me-mm-linkage-2026-27` — 最優先。他3 spec の前提（CategoryLineageMap/Linker を提供）
3. `/kiro-impl ajocc-point-267-prod` — 依存なし（2と順序入替可）
4. `/kiro-impl catracer-cleanup-2026-27` → `/kiro-impl season-rules-2026-27` → `/kiro-impl jcx-lineage-lock-2026-27`
5. 結合試験（ローカルダンプで是正バッチ検証含む）→ PR。**期限 2026-07-31**（roadmap にスケジュール表）

実装時フォローアップ（クロスレビュー minor 指摘、roadmap「Cross-Spec Review」節）:
- me-mm-linkage: category_racers 保存経路 13/14 の差分1経路をバリデーション実装前に再 grep で特定
- Wave1（me-mm-linkage）のテストフィクスチャ完了を確認してから後続 spec の実装に着手（重複定義防止）

## エージェント構成（2026-07-15 ユーザー合意・厳守）

- 同時起動は**オーケストレーター（Fable 5 本体）＋サブエージェント1体まで**。並列禁止・逐次実行
- モデル: 調査=Haiku 4.5（Explore）/ 実装・レビュー・デバッグ=Sonnet 5 / 最重要ゲート検証=本体直接
- 中断（利用上限等）時は SendMessage 再開（新規起動しない）。サブエージェントは要約のみ返却
- 背景と sdd_base_template への反映ガイド: `.kiro/specs/sdd-agent-tiering-2026-07/handover.md`
  （テンプレート反映は別リポジトリ作業として未着手）

## 主要な合意事項（詳細は各 spec の agreement-log.md と roadmap.md）

- 連動モデル: **案A（対応ペア両保有）**。ME1⇔MM1（MM1→ME1は元ME1のみ）/ME2⇔MM1/ME3⇔MM2/ME4⇔MM3。
  女子系統は対象外と確定（WM は年齢制単一カテゴリー）
- 二重付与防止: **エラーで弾く**（自動整合しない）
- 既存データ是正: **直近の出走実態**基準・任意タイミング実行・冪等・logonly あり
- JCX 系統固定: **案B（警告+管理者確認）だが警告と回避誘導は強め**（Requirement 5 AC7）。
  リザルト取込は警告記録のみ、内部エラーは fail-open
- コミットは人間が実行（自動コミット禁止）。TDD 必須

## ドメイン知識の要点

- カテゴリーコード: ME1〜ME4=`C1`〜`C4`、MM1〜MM3=`CM1`〜`CM3`、WE1=`CL1`（categories.code）
- 認定は `category_racers`（cancel_date=NULL が有効。履歴は物理削除せず cancel_date+reason で終了）
- 昇格リアルタイム処理: `app/Controller/Component/ResultParamCalcComponent.php`
  （me-mm-linkage / season-rules / ajocc-point-267-prod の3 spec が触るが**メソッドレベルで非衝突を
  検証済み**）
- 既知の落とし穴: WE1 集計は `races_category_code IN ('CL1','UCIWE')`（UCIWE 漏れ厳禁）。
  AJOCC ポイントは `tmp_ajoccpt_racer_sets` 全国版（`ajoccpt_local_setting_id IS NULL, type=1`）
- ルール改正原文: https://www.cyclocross.jp/news/2026/07/20262027amendment.html
  新ポイント表 PDF: https://www.cyclocross.jp/2026/2026-2027ajoccpointtable.pdf
