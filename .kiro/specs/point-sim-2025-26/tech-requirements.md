# 技術要件確認: 2025-26 新ポイントテーブル ランキングシミュレーション

| 項目 | 内容 |
|---|---|
| タスクID | `point-sim-2025-26` |
| 作成日 | 2026-06-14 |
| 確認者 | Claude Code |

---

## 言語・フレームワーク・ライブラリ

| 項目 | バージョン | 制約・備考 |
|---|---|---|
| 言語 | PHP 7.3.20 | コンテナ `cyclox2_svr` |
| フレームワーク | CakePHP 2.10.24 | レガシー2.x系 |
| DB | MySQL 5.7.42 | DB名 `cyclox2` |
| 依存管理 | なし（vendor未使用） | composer未導入 |

---

## テスト環境

| 項目 | 内容 |
|---|---|
| PHPUnit | **未導入**。CakePHP 2.10系は PHPUnit 3.7（PHP7非互換）に依存するため正式ハーネス導入は非現実的 |
| 採用するテスト方式 | **Console製アサーション・ハーネス**（CakePHP Shell）。テスト可能なpublicシームを利用 |
| テスト対象シーム① | `ResultParamCalcComponent::calcAjoccPt($rank,$startedCount,$meetDate,$isJcx)`（public・DB非依存） → System①の値検証 |
| テスト対象シーム② | `PointCalculator::getCalculator(13)->calc($result,$grade,...)`（public） → System②の値検証 |
| テスト実行コマンド | `docker-compose exec cyclox2_svr bash -c "cd /var/www/html/app && Console/cake PointSim testTables"` |
| TDD手順 | 期待値（スプレッドシート由来）をアサーションとして先に記述→RED確認→実装→GREEN確認 |

---

## 既存コードとの結合

| 項目 | 内容 |
|---|---|
| 変更ファイル① | `app/Controller/Component/ResultParamCalcComponent.php`（`__getAjoccPointMap`に日付分岐追加） |
| 変更ファイル② | `app/Cyclox/Util/PointCalculator.php`（`AJOCC_267_TEST` val=13 追加） |
| 新規ファイル | `app/Console/Command/PointSimShell.php`（テスト・再計算バッチ・CSV出力） |
| DB変更 | 2025-26 `point_series.calc_rule` 11→13（season_id=16、**23件**） |
| マイグレーション | 不要（直接UPDATE、開発環境のみ） |

---

## 環境固有の制約

| 制約 | 内容 |
|---|---|
| PHP 7.3 / CakePHP 2.10 | モダンなテストツール不可。Console方式で対応 |
| DBは本番ダンプ | `tmp/`にダンプ確保済み。開発環境のみ。本番非影響 |
| キャッシュ汚染 | `calcAjoccPt`のポイント表キャッシュをバッチで都度破棄（design.md参照） |

---

## リスク・対応

| リスク | 対応策 |
|---|---|
| テストハーネス非整備 | Console製アサーションで自動・反復可能なTDDを担保 |
| privateメソッド検証不可 | publicシーム(`calcAjoccPt`)経由で間接検証 |
| 26-27適用でDB上書き | 変更前にベースラインCSVを退避（T0） |

---

## 承認

- [x] ClaudeCode が上記内容を確認した
- [x] 人間が技術要件・テスト方式を確認し実装着手を承認（2026-06-14、「すすめて」）

## 実績補足（2026-06-15）
- 再計算バッチは `OneTimeShell` ではなく専用 `PointSimShell` に集約して実装。
- 変更ファイル①②（PointCalculator / ResultParamCalcComponent）に加え、`resetAjoccPtCache()` を新設。
- DB付替えは `calc_rule=11→13`（season_id=16、**23件**）で実施。
- 詳細な結果は `test-results.md`、設計差分は `design.md`「実装結果・設計差分」を参照。
