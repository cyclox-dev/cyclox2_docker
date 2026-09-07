# 結合試験チェックリスト: catracer-cleanup-2026-27

| 項目 | 内容 |
|---|---|
| タスクID | `catracer-cleanup-2026-27` |
| 作成日 | 2026-09-07 |
| 確認者 | Claude Code |
| 確認日 | 2026-09-07 |
| 実施環境 | Docker（`cyclox2_svr` / `cyclox2_mysql`）、`feat/catracer-cleanup-2026-27` ブランチのコードを配信中 |
| DB保全 | 開発DB（`cyclox2`、`category_racers` 267,917行）に対して直接実行。バックアップは未取得（開発環境のため。本番適用時はrunbook.md step 1のバックアップを必須とする） |

> 単体・統合テストの結果、およびローカルダンプでの実行検証の実測値は
> `.kiro/specs/catracer-cleanup-2026-27/test-results.md` を参照。
> CLIバッチのため、管理画面での確認項目はない。

---

## 実施した試験のシナリオ

開発DB（本番相当データ、267,917行）に対し `detect → cleanup logonly → cleanup → verify`
を通しで実行し、CLIの実出力とDBの実状態で結合動作を確認した。

| 項目 | 内容 |
|---|---|
| 検証対象 | `cake cat_racer_cleanup {detect,cleanup,verify}`（全サブコマンド） |
| 対象DB | `cyclox2`（開発環境、本番相当データ） |
| 検出規模 | 406選手・858件（対応外ペア・同一系統内複数保有・重複保有・3件以上同時保有の混在） |
| 是正規模 | 13選手（FIX判定、cancel+grant各13件） |

---

## 事前確認

- [x] 稼働中のコンテナに実装済みコードを配信している（`app/Console/Command/CatRacerCleanupShell.php`はホストとバインドマウントのため常に最新）
- [x] `cyclox2_svr` / `cyclox2_mysql` コンテナが起動している
- [x] 開発環境DBに対応表管理対象カテゴリー・出走実績データが存在する（267,917行規模）
- [x] `category_racers` テーブルがInnoDBエンジンである（トランザクション・ロールバックの前提。開発DBで確認済み）

---

## 実施した試験

| # | シナリオ | 実行コマンド | 期待結果 | 実際結果 | 合否 |
|---|---|---|---|---|---|
| 1 | 検出のみ（書き込みなし） | `cake cat_racer_cleanup detect` | 違法保有選手を報告、DB無変更 | 406選手・858件検出、0.39秒 | ✅ |
| 2 | 試算（logonly、全ロールバック） | `cake cat_racer_cleanup cleanup '' '' logonly` | FIX/MANUAL/DUP_ONLY内訳を報告、DB無変更 | FIX13/MANUAL98/DUP_ONLY295、3分33秒 | ✅ |
| 3 | 本実行（実書き込み） | `cake cat_racer_cleanup cleanup` | logonly試算と同一の内訳で是正確定 | 内訳完全一致、異常終了なし、2分15秒 | ✅ |
| 4 | 検証（残存違法報告） | `cake cat_racer_cleanup verify` | 残存393選手（MANUAL98+DUP_ONLY295） | 393選手・832件、内訳一致 | ✅ |
| 5 | 冪等性（再実行） | 単体テスト`testCleanupIsIdempotentSecondRunMakesNoAdditionalChanges`で確認 | 是正済み選手は再実行で変更なし | 確認済み（フィクスチャベース） | ✅ |
| 6 | 専用ログへの記録 | `app/tmp/logs/catracer_cleanup.log` を確認 | 各サブコマンドの実行結果が記録される | 記録を確認 | ✅ |

---

## 実施後の状態

- 開発DB（`cyclox2`）の`category_racers`は、13選手分の是正（反対系統終了＋対応カテゴリー付与）が
  **確定済みのまま**（本試験は本番適用のリハーサルを兼ねるため、意図的にロールバックしていない）。
  これは開発DBの実態をme-mm-linkage-2026-27運用開始に近づける効果があるため許容する
  （元に戻す場合はrunbook.md「8. ロールバック手順」を使用）。
- 残存する393選手（MANUAL98・DUP_ONLY295）は、`outputs/manual-review-list.md`（MANUAL分）と
  既存の重複是正手段（DUP_ONLY分）による別途対応が必要。runbook.md「7. 残存分の後続対応」参照。

---

## 未実施・今後の課題

- [ ] 実際の本番DBに対する適用（本specの完了条件外。runbook.mdに従い人間の判断で別途実施）
- [ ] MANUAL 98件の個別確認（`outputs/manual-review-list.md`を人間が確認）
- [ ] DUP_ONLY 295件の既存重複是正手段による対応（本specのスコープ外）
