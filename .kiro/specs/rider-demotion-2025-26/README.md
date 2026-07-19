# 2025-26シーズン ライダー降格処理（rider-demotion-2025-26）

AJOCC公式残留基準に基づくカテゴリー降格処理。ローカルコンテナで実行・検証済み（583件＋重複修正1件）。
本番反映（A案: 検証済みSQLを適用）は別途人間が実施。

## このディレクトリの構成
| パス | 内容 | git |
|---|---|---|
| `runbook.md` | **再利用手順書（次年度はこれを参照）** | ✅追跡 |
| `agreement-log.md` | 合意形成記録（決定・却下・承認） | ✅追跡 |
| `tech-requirements.md` | 技術要件 | ✅追跡 |
| `test-results.md` | テスト/検証結果 | ✅追跡 |
| `integration-test-checklist.md` | 公開ランキング照合・DB整合・本番反映チェック | ✅追跡 |
| `sql/` | 再利用スクリプト（判定・生成・検証） | ✅追跡 |
| `outputs/` | downlist / koukaku SQL / 実行ログ / 検証メモ（**PII**） | 🚫git管理外 |

関連: `.kiro/specs/rider-demotion-2025-26/`（requirements / design / tasks / spec.json）

## 結果サマリー（2025-26）
- 降格: ME1(C1→C2)93 / ME2(C2→C3)107 / ME3(C3→C4)202 / MM1(CM1→CM2)48 / MM2(CM2→CM3)113 / WE1(CL1→CL2)20 = **583名**
- 重複修正: `CCM-000-7350`（終了漏れCM1 id=721を終了、CM2→CM3で降格）
- 公開ランキング照合: 全6カテゴリー一致。照合過程で**WE1のUCIWE取りこぼしバグを検出・修正**（21→20）。

## 次にやるとき
`runbook.md` の手順どおり実行し、「次年度の更新点」（season_id・期間・残留ライン・集計race_category）だけ差し替える。
