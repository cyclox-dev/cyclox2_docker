# 合意形成記録: 2026-27シーズン 昇格・残留・降格ルール改定

| 項目 | 内容 |
|---|---|
| タスクID | `season-rules-2026-27` |
| 作成日 | 2026-07-14 |
| 関係者 | KYamada / Claude Code |

---

## 壁打ち概要

AJOCC 2026-27規則改正（https://www.cyclocross.jp/news/2026/07/20262027amendment.html）対応
プロジェクトの一部として、昇格・残留・降格のルール値と判定方法の変更を扱う。
ディスカバリーセッション（roadmap.md / brief.md）で以下を整理済み：

- 対応は二層：(a) リアルタイム昇格枠（MM2→MM1=最大3名）はアプリコード
  （`ResultParamCalcComponent`）のシーズン切替パターンで対応、(b) シーズン末残留・降格判定は
  `rider-demotion-2025-26` の runbook/SQL 資産を新ルール対応版に改訂
- 系統横断残留判定は upstream spec `me-mm-linkage-2026-27` の対応表を前提とする（重複定義禁止）
- 2026-27シーズン末降格の本番実行（2027-03）はスコープ外（人間が runbook に従い実施）
- 期限 2026-07-31（判定ロジック実装・runbook 改訂・ローカル検証完了まで）

---

## 決定事項

| # | 決定内容 | 決定理由 | 決定日 |
|---|---|---|---|
| 1 | リアルタイム昇格枠の変更は `ResultParamCalcComponent` の既存シーズン切替パターン（`__rule*` 配列 + `_isSeasonAfterEqXXXX()` 分岐）を踏襲する | 過去シーズン非影響の要件を既存実績のある方式で満たせる。2015-16〜24-25 の切替が同方式で運用済み | 2026-07-14 |
| 2 | シーズン末判定は SQL/runbook 方式を維持し、アプリコード化しない | rider-demotion-2025-26 で確立・検証済みの方式。年1回の人間実行プロセスに適合 | 2026-07-14 |
| 3 | 系統横断残留・連動降格の対応関係は `me-mm-linkage-2026-27` の `CategoryLineageMap`（C4⇔CM3, C3⇔CM2, C2⇔CM1, C1→CM1）と同一の対応表に従う。SQL 内の対応ペア定義には出典コメントを付し、対応表変更時の追随を Revalidation Trigger とする | 対応表の単一ソース原則（roadmap Shared seams）。SQL は PHP クラスを参照できないため、値の複製に出典明記で対処 | 2026-07-14 |
| 4 | 新 runbook/SQL 資産は `.kiro/specs/season-rules-2026-27/` 配下に置く（`docs/specs/` は使わない） | CLAUDE.md の「新規タスクは `.kiro/specs/<task-id>/` を使う」ルールに準拠 | 2026-07-14 |
| 5 | シーズン今季昇格者の降格除外（基準3）は維持し、系統横断判定においては「昇格除外＝当該カテゴリー残留」として扱い、対応ペアの相手側も救済する | me-mm-linkage の連動昇格により両系統同時昇格が正常系となるため、片系統のみの除外は矛盾を生む | 2026-07-14 |
| 6 | WE1 の新基準（80位以内）の順位ソースは全国版 AJOCC ランキング（`tmp_ajoccpt_racer_sets`, `ajoccpt_local_setting_id IS NULL`, `type=1`）とし、出走集計は `races_category_code IN ('CL1','UCIWE')` を維持する | 2025-26 の UCIWE 取りこぼし事故の再発防止（requirements Requirement 8） | 2026-07-14 |
| 7 | ローカル検証は 2025-26 データダンプ（season_id=16）への新ルール適用シミュレーションで行い、結果は `test-results.md` に記録する。2025-26 実績（旧ルール 583名）との差分を説明可能にする | 2026-27 の実データはまだ存在しないため、既知の結果を持つ 2025-26 データが唯一の検証基盤 | 2026-07-14 |

---

## 却下・保留事項

| 内容 | 理由 |
|---|---|
| 残留ライン・昇格枠を DB テーブル管理（パラメータテーブル新設）にする案 | スキーマ変更を伴い期限リスクが高い。年1回の変更頻度に対し過剰。コード/SQL 冒頭への値集約（Requirement 6）で十分と判断 |
| シーズン末判定のアプリコード（Shell）化 | 検証済み SQL 資産の作り直しとなり期限内完了リスク。既存 runbook 方式の改訂で対応 |

---

## フェーズゲート承認記録

> 承認状態の正本は `.kiro/specs/season-rules-2026-27/spec.json` の
> `approvals.{requirements,design,tasks}.approved`。
> ここではブール値を二重管理せず、合意の経緯・補足のみを残す。

| フェーズ | 合意メモ（理由・補足） |
|---|---|
| 要件定義（requirements.md） | roadmap 承認済みスコープ（2026-07-14 ユーザー合意）に基づき自動承認モード（-y 相当）で生成。8要件・EARS形式 |
| 設計（design.md） | 同上。既存コード（ResultParamCalcComponent / rider-demotion-2025-26 SQL資産）の実測に基づく拡張設計。me-mm-linkage-2026-27 との共有シーム（ResultParamCalcComponent）を Boundary Commitments に明記 |
| タスク分解・実装前確認（tasks.md） | 同上。TDD 必須（アプリコード）・ローカルダンプ検証必須（SQL/runbook）をタスクに織込み |

---

## 変更履歴

| 日付 | 変更内容 | 変更者 |
|---|---|---|
| 2026-07-14 | 初版作成（spec 生成パイプラインの一部として） | Claude Code |
