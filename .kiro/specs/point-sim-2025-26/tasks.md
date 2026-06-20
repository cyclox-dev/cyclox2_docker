# タスク: 2025-26 新ポイントテーブル ランキングシミュレーション

タスクID: `point-sim-2025-26`
作成日: 2026-06-14 / 最終更新: 2026-06-20
ステータス: **完了**（2026-06-20 PR #12 レビュー対応として T11 本番隔離フラグを追補）
作業ブランチ:
- アプリ本体（submodule cyclox2web）: `feat/point-table-ajocc-267-sim`（PR #12）
- dockerリポ: `claude/romantic-lalande-4bb2be`（PR #8）

> 当初 `feat/point-table-ajocc-256-sim` を仮置きしたが、命名規則（26-27=267）に合わせ
> `feat/point-table-ajocc-267-sim` で確定・コミットした。

## 実装タスク（実績）

### T0: ベースライン退避（変更前の現行データ）✅
- [x] 現行（=25-26ルール）の AJOCCランキングCSV(29)・JCF/JCXシリーズCSV(23) を退避
- [x] 25-26テーブルは現行本番と完全一致のため 25-26用の改修は不要（合意#8）

### T1: 技術要件確認 ✅
- [x] `tech-requirements.md` を記入
- [x] テスト方式を確定：PHPUnit非導入のため **Console製アサーション・ハーネス**でTDD

### T2: System① AJOCCポイント表の追加（TDD）✅
- [x] テスト先行（人数境界・JCX列順位）
- [x] `__getAjoccPointMap` に `$divDate2025`(>=2025-08-01) 分岐＋新8区分表＋JCX列を実装
- [x] テストGREEN

### T3: System② シリーズ計算器の追加（TDD）✅
- [x] テスト先行（グレード非依存）
- [x] `PointCalculator` に `AJOCC_267_TEST`(val=13)・`__calcAJOCC267Test`・table・switch を実装
- [x] テストGREEN

### T4: 再計算バッチの実装 ✅
- [x] `PointSimShell::recalcSeason(seasonId)` を実装（※OneTimeShellではなく専用シェルに集約）
- [x] **カテゴリ毎に新インスタンス生成**（`__started`累積バグ対策）／リザルト有のみ対象／try-catch
- [x] 単一カテゴリ(`recalcOne`)で値検証（24883→250, 26651→350）

### T5: データ移行（DB）✅
- [x] 2025-26 `calc_rule=11`→`13` UPDATE（`season_id=16`限定、**23件**）

### T6: 再計算実行 ✅
- [x] `recalcSeason 16` 実行 → `total=1170 ok=1170 skip=0 ng=0`

### T7: 回帰確認 ✅
- [x] 2024-25(season15)の `ajocc_pt` が旧3段階(180/150/100)のまま＝不変を確認

### T8: ランキングCSV出力 ✅
- [x] `PointSimShell::exportAjocc` でAJOCC29カテゴリ出力（既存`download_ajocc_pt_csv`同形式）
- [x] `PointSimShell::exportSeries` でJCF/JCXシリーズ23本出力（`calcUpSeries`同形式）
- [x] `outputs/baseline/` `outputs/after_2627/` に保存（git管理外）

### T9: 記録・結合試験 ✅
- [x] `test-results.md` 記録
- [x] `integration-test-checklist.md` 作成
- [x] `agreement-log.md` 承認欄・実績を更新

### T10: 追加分析・クライアント提出（追加依頼）✅
- [x] 降格ライン分析（公式規定 cyclocross.jp 準拠）：マスターズ点数基準／エリート順位基準
- [x] `comparison-summary.md` に降格ライン分析を追記
- [x] クライアント向けPPT `ranking_simulation_analysis.pptx` を作成（QA済み）
- [x] 提出用フォルダ/zipを整理（Driveアップロードは人間側で対応）

### T11: 本番フロー隔離フラグ（PR #12 レビュー対応）✅ 2026-06-20
- [x] 要件 R6 を追加（シミュレーション専用フラグ／本番デフォルト無効）
- [x] `ResultParamCalcComponent` に `__simAjocc267` フラグ＋ `enableSimAjocc267()`/`disableSimAjocc267()` を実装
- [x] `__getAjoccPointMap` の日付分岐を `$this->__simAjocc267 &&` でガード（本番は従来表へフォールバック）
- [x] `PointSimShell`（startup / recalcSeason）で `enableSimAjocc267()` を呼ぶ（既存フローは無改修）
- [x] `testTables` に「本番OFF=180/200 ⇔ シムON=350/1000」の対比アサーションを追加
- [x] 実コードハーネス（PHP8.3）でフラグOFF=従来値・ON=267・回帰不変を検証（8/8 PASS）
- [ ] Docker 上での `testTables` 再実行・Web 経由の最終確認（integration-test-checklist に記載、人間確認）

## コミット・反映（実績）
- main直コミットなし。submodule・dockerとも作業ブランチ→push→PR で反映。
- 生成物CSV/PPT（個人情報含む）は `docs/specs/*/outputs/` を `.gitignore` し履歴に含めない。
