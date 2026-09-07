# テスト結果記録: catracer-cleanup-2026-27

| 項目 | 内容 |
|---|---|
| タスクID | `catracer-cleanup-2026-27` |
| 実行日 | 2026-09-07 |
| 実行者 | Claude Code |
| テストフレームワーク | PHPUnit 3.7.38（CakePHP 2.10.24 組込みテストランナー経由） |
| 実行コマンド | `docker exec cyclox2_svr bash -lc "cd /var/www/html/app && ../lib/Cake/Console/cake test app <対象パス>"` |
| 実行環境 | Docker（`cyclox2_svr` コンテナ、`cyclox2_mysql` 接続。ホストPHPはバージョン不一致のため直接実行不可） |

---

## 単体・統合テスト結果サマリー（task 4.3, 5.1）

| スイート | テスト数 | アサーション数 | 結果 |
|---|---|---|---|
| `Console/Command/CatRacerCleanupShellTest` | 46 | 254 | ✅ OK |
| `Model/CategoryRacerTest`（回帰確認） | 16 | 77 | ✅ OK |
| `Cyclox/Util/CatRacerCleanupJudgeTest`（回帰確認） | 31 | 150 | ✅ OK |

task 5.1の統合テスト（`testFullFlowDetectCleanupVerifyResolvesFixTargetsAndReportsResidualManualCases`）で、
detect → cleanup → verify の一気通貫フローが以下を満たすことを確認:
- FIX対象（対応外ペア）はcleanup後にDBが是正され、verifyで違法保有として検出されなくなる
- MANUAL/DUP_ONLY判定の選手はcleanup前後でDBが一切変更されない
- 合法選手（正当な対応ペア保有）はcleanup前後で有効保有が変化しない
- MANUAL判定で未是正の選手は、verifyで残存違法保有として明示的に報告される
- 是正後の全対象選手について、上流の有効集合検証（`CategoryLineageLinker::isValidActiveSet()`）に適合する

---

## ローカルダンプでの実行検証（task 5.2）

開発DB（`cyclox2` データベース、コンテナ `cyclox2_mysql`、`category_racers` 267,917行規模の
本番相当データ）に対し、`detect → cleanup logonly → cleanup → verify` を通しで実行した。

### 実行結果

| ステップ | 検出/対象選手数 | 内訳 | 所要時間 |
|---|---|---|---|
| 1. `detect`（書き込みなし） | 406選手・858件 | — | 0.39秒 |
| 2. `cleanup logonly`（書き込みなし・全ロールバック） | 406選手 | FIX 13 / MANUAL 98 / DUP_ONLY 295 / OK 0 | 3分33秒 |
| 3. `cleanup`（本実行・実書き込み） | 406選手 | FIX 13 / MANUAL 98 / DUP_ONLY 295（是正: 終了13件・付与13件） | 2分15秒（異常終了なし） |
| 4. `verify`（書き込みなし） | 393選手・832件が残存 | — | 0.39秒 |

- ステップ2とステップ3の判定結果（FIX/MANUAL/DUP_ONLY内訳）が完全一致することを確認した
  （logonlyモードの判定・分類がロールバック有無に関わらず本番同等であることの実測裏付け）。
- ステップ3実行後、`category_racers`は13名分の是正（対応外ペアの反対系統終了＋対応カテゴリー
  付与）のみが反映され、他選手は無変更であることをステップ4のverify結果から確認した
  （残存393選手 = ステップ2/3が報告したMANUAL 98 + DUP_ONLY 295と一致）。

### 完了条件（violate ペアゼロ）について

design.md記載の完了条件「verifyが違法ペアゼロを報告している」は、**本バッチが自動是正するFIX
（対応外ペア）対象に限っては達成された**（13件全て是正済み、verifyで検出されない）。ただし
以下2種は本バッチの設計上意図的にスコープ外であり、cleanup単体では違法ペアゼロに至らない:

- **DUP_ONLY（295件）**: 「完全重複起因のみ・既存手段案内」（design.md）。既存の
  `OneTimeShell::setupDuplicatedCatRacerDeleted()`（合意事項の却下・保留欄参照）で別途対応する
  対象であり、本バッチは検出・報告のみ行い是正しない（brief.mdのOut of Boundary）。
- **MANUAL（98件）**: 出走実績なし（3件）・系統判定不能に起因する手動確認対象
  （93件がKEEP_LINEAGE_HOLDING_COUNT_INVALID、2件がDUPLICATE_HOLDING_UNSAFE_FIX）。
  人間の個別判断に回す一覧を`outputs/manual-review-list.md`（PII含むためgit管理外）に記録した。

したがって「違法ペアゼロ」という最終状態は、本バッチ（FIX自動是正）＋既存の重複是正手段
（DUP_ONLY対応）＋人間による個別判断（MANUAL対応）の3つを組み合わせて初めて到達する。
この運用手順は`runbook.md`に記載した。

---

## 手動確認対象一覧

`outputs/manual-review-list.md`（PIIを含むためgit管理外、`.kiro/specs/catracer-cleanup-2026-27/outputs/`）
に98件の選手コード・氏名・違法種別・判定根拠・MANUAL理由を記録した。
