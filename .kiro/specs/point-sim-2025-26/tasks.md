# タスク: 2025-26 新ポイントテーブル ランキングシミュレーション

タスクID: `point-sim-2025-26`
作成日: 2026-06-14
作業ブランチ: `cyclox2_svr/cyclox2` の `feat/point-table-ajocc-256-sim`

## 実装タスク

### T0: ベースライン退避（変更前の現行データ）
- [ ] T0.1: 変更前に、現行（=25-26ルール）の AJOCCランキングCSV・JCF/JCXシリーズランキングCSV を出力・退避（26-27比較の基準）
- [ ] 備考: 25-26テーブルは現行本番と完全一致のため、25-26用の改修作業は不要（合意#8）

### T1: 技術要件確認（初回実装）
- [ ] `docs/specs/point-sim-2025-26/tech-requirements.md` を確認・記入
- [ ] テスト実行方法（CakePHP 2.x / PHPUnit）の確認

### T2: System① AJOCCポイント表の追加（TDD）
- [ ] T2.1: テスト先行 — 新8区分表の人数境界テスト、新JCX列の順位テストを記述
- [ ] T2.2: `__getAjoccPointMap` に `$divDate2025` 分岐と新表（8区分＋JCX列）を実装
- [ ] T2.3: テストGREEN確認

### T3: System② シリーズ表の追加（TDD）
- [ ] T3.1: テスト先行 — `AJOCC_267_TEST` 計算器の順位テスト（グレード非依存）
- [ ] T3.2: `PointCalculator` に `AJOCC_267_TEST`(val=13)・`__calcAJOCC267Test`・table・switch分岐を実装
- [ ] T3.3: テストGREEN確認

### T4: 再計算バッチの実装
- [ ] T4.1: `OneTimeShell::recalcSeason(seasonId)` 実装（キャッシュ破棄を含む）
- [ ] T4.2: 少数カテゴリーで動作確認（ドライ的に1大会のみ）

### T5: データ移行（DB）
- [ ] T5.1: 2025-26 `calc_rule=11`→`13` UPDATE（事前に件数35を確認、`season_id=16`限定）

### T6: 再計算実行
- [ ] T6.1: `recalcSeason 16` を実行（1,192カテゴリー）
- [ ] T6.2: ログ確認、失敗カテゴリーの有無を確認

### T7: 回帰確認
- [ ] T7.1: 2024-25代表カテゴリーの `ajocc_pt` が不変であることを確認

### T8: ランキングCSV出力
- [ ] T8.1: AJOCCランキングCSV出力（`download_ajocc_pt_csv` 同形式）
- [ ] T8.2: JCF/JCXシリーズランキングCSV出力（`calcup`→`download_point_ranking_csv`）
- [ ] T8.3: 出力CSVを成果物として保存

### T9: 記録・結合試験
- [ ] T9.1: `docs/specs/point-sim-2025-26/test-results.md` にテスト結果記録
- [ ] T9.2: `docs/specs/point-sim-2025-26/integration-test-checklist.md` 作成
- [ ] T9.3: agreement-log.md のフェーズゲート承認欄を更新

## コミット方針
- フェーズ区切りでコミット推奨を提示（自動コミット切替可）。
- `main` への直接コミット禁止。ブランチ→push→PR。
- submodule（`cyclox2_svr/cyclox2`）側と docker側（`docs/`等）で別リポジトリのため、コミットは各々で行う。
