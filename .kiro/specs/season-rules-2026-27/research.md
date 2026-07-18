# Research & Design Decisions

## Summary
- **Feature**: `season-rules-2026-27`
- **Discovery Scope**: Extension（既存システムの拡張。アプリコード＋SQL/runbook 資産の二層）
- **Key Findings**:
  - リアルタイム昇格枠は `ResultParamCalcComponent::__setupRankUpRules()` の
    「シーズン判定分岐 × ルール配列」パターンで管理されており、2026-27 用の分岐追加は
    既存パターンの複製で実現できる（過去シーズン非影響が構造的に保証される）
  - シーズン末降格の SQL 資産（rider-demotion-2025-26）は「カテゴリー単位・系統独立」の
    判定構造であり、系統横断残留判定の導入には判定セット生成 SQL の2段化
    （自基準充足判定 → 横断救済適用）が必要
  - 従来「二重降格＝異常」だった検証基準が、連動降格の導入により
    「対応ペアの同時降格＝正常、同系統内の二重降格＝異常」に変わる。検証 SQL の再定義が必須

## Research Log

### ResultParamCalcComponent の昇格ルール構造
- **Context**: MM2→MM1 昇格上限を 2026-27 シーズンから 3 名に変更する方法の確認
- **Sources Consulted**: `cyclox2_svr/cyclox2/app/Controller/Component/ResultParamCalcComponent.php`
  （submodule commit 33c3aede）
- **Findings**:
  - ルール配列はメンバ変数として先頭に集約されている（L45-90）。
    `__rule011122 = [40人以上→2名, 10人以上→1名]` が現行の CM2→CM1 ルール
  - `__setupRankUpRules()`（L1853-1927）がシーズン判定分岐で `__rankUpMap` を構築。
    分岐は `_isSeasonAfterEq2425()`（L1985: `__atDate > '2024-03-31'`）等の日付比較メソッド。
    24-25 分岐が最上位で、C2→C1 のみ `__rule013533`（50→3, 30→2, 10→1）に差し替えた前例あり
  - `CM2` と `CM2+3` は同じルール配列を共有する（`'CM2+3' => ['to' => 'CM1', 'rule' => __rule011122]`）。
    CM2 の枠変更時は CM2+3 も同時に変更する必要がある
  - `CM1+2+3` レースは別経路（L613-641: 優勝→CM1、表彰台→CM2）でルール配列を使わない。
    今回の改正対象外（枠数の概念がない）
  - 少人数昇格の特例（L813: `'2021-04-01'` 以降 CM2/CM3）も本改正の対象外
- **Implications**: 新ルール配列1個＋シーズン判定メソッド1個＋分岐1個の追加で足りる。
  既存分岐・配列は一切変更しないため過去シーズンへの影響はない

### me-mm-linkage-2026-27 との共有シーム
- **Context**: 同一ファイル（ResultParamCalcComponent）を両 spec が変更するため競合範囲の特定
- **Sources Consulted**: `.kiro/specs/me-mm-linkage-2026-27/design.md`（承認済み）
- **Findings**:
  - me-mm-linkage の変更点は `__execApplyRankUp()` / `__applyRankUp2CM()` の末尾への
    `CategoryLineageLinker::propagateLinkedPromotion()` フック追加（L1060-, L1218- 付近）
  - 本 spec の変更点は `__setupRankUpRules()`（L1853-）とルール配列宣言部（L45-90）、
    シーズン判定メソッド群（L1929-1992）
  - 変更箇所はメソッド単位で重ならない。テストファイル
    `app/Test/Case/Controller/Component/ResultParamCalcComponentTest.php` は me-mm-linkage が
    新規作成予定（現状存在しないことを実測確認済み）のため、本 spec はそれに追記する形をとる
  - HoldPoint は me-mm-linkage が「昇格元系統にのみ1回付与」と決定済み。本 spec の残留判定は
    HoldPoint を直接は使わない（AJOCC ランキング `tmp_ajoccpt_racer_sets` が判定ソース。
    HoldPoint はランキング集計の内部要素として既に織込み済み）
- **Implications**: ファイル共有はあるが行レベル競合はない。実装 Wave（me-mm-linkage が先行）
  を前提に、本 spec のテストは me-mm-linkage が整備するテスト基盤（Fixture 群）を再利用する

### rider-demotion-2025-26 SQL 資産の構造
- **Context**: シーズン末判定 SQL の改訂範囲の特定
- **Sources Consulted**: `docs/specs/rider-demotion-2025-26/`（runbook.md, sql/01_build_demote_set.sql,
  sql/02_gen_koukaku.sh, sql/03_verify.sql, README.md, tech-requirements.md）
- **Findings**:
  - `01_build_demote_set.sql`: カテゴリーごとに独立した INSERT 文で `demote_all` テーブルを構築。
    判定 3 基準（順位/点数ライン・無出走・今季昇格者除外）が WHERE 句に直書き。
    パラメータ（`@s`, `@pf`, `@pt`）は冒頭 SET 文だが、残留ライン値（240/260/280, 80/40）は
    各 INSERT 文内にリテラルで埋め込まれている
  - `02_gen_koukaku.sh`: `demote_all` から src 別 downlist を出し、INSERT（降格先）+
    UPDATE（旧所属終了）の SQL を機械生成。降格先マッピングはスクリプト内の `gen_sql` 呼び出しに直書き
  - `03_verify.sql`: 「二重降格（同一 racer が 2 回 INSERT）= 0 期待」を検証している。
    連動降格導入後はこの検証が偽陽性になる（対応ペアの 2 行は正常）
  - 集計対象: ME/MM は全国版ランキング（`ajoccpt_local_setting_id IS NULL`, `type=1`）、
    合計点は `sumup_json` 先頭要素を `SUBSTRING_INDEX` で抽出（MySQL 5.7 のため JSON 関数不使用）。
    WE1 出走は `races_category_code IN ('CL1','UCIWE')` + `status<>0`
  - 2025-26 実績: C1=93 / C2=107 / C3=202 / CM1=48 / CM2=113 / CL1=20 = 583 名
- **Implications**: 改訂は (1) 残留ライン値の冒頭変数化、(2) 判定の 2 段化（自基準充足 →
  系統横断救済 → 降格セット）、(3) verify の「二重降格」再定義、(4) WE1 の判定を
  出走基準から順位基準（80位）へ変更、の4点。生成スクリプト（02）は downlist の意味が
  変わらないため小改訂で済む

### 系統横断残留判定の SQL 表現
- **Context**: Requirement 3〜5 を MySQL 5.7 で表現する方式の検討
- **Sources Consulted**: 01_build_demote_set.sql の既存構造、me-mm-linkage design の対応表定義
- **Findings**:
  - 降格判定対象カテゴリーは C1, C2, C3, CM1, CM2, CL1（C4/CM3/CL2 以下は最下位で降格なし）
  - 系統横断が作用する対応ペアは C2⇔CM1 と C3⇔CM2 の 2 組のみ。
    C1⇔CM1（元ME1ペア）は「C1 は C1 成績のみで判定（ME1例外）、CM1 は C1 成績でも救済可」
    という非対称になる
  - 判定を「(a) racer×category の自基準充足フラグ表を作る →
    (b) 有効保有ペアと突合して救済を適用し降格セットを作る」の 2 段に分けると、
    各段が単純な結合で書け、中間表を目視検証できる（Requirement 7.3 の確認可能性にも合致）
  - 今季昇格者除外（基準3）は (a) 段で「充足扱い」にすると、(b) 段の救済ロジックが
    自然に相手系統へも波及する（agreement-log 決定事項 5）
- **Implications**: `01_build_demote_set.sql` を「survive_flags（中間表）→ demote_all」の
  2 段構成に改訂する設計とする

### WE1 新基準（80位以内）の順位ソース
- **Context**: WE1 は従来出走のみで残留だったため、順位判定のソース確認が必要
- **Sources Consulted**: 01_build_demote_set.sql（C1〜C3 の順位判定パターン）、
  runbook.md §2 カテゴリーマッピング表（CL1 の集計 race_category は CL1, UCIWE）
- **Findings**:
  - ME 系と同じ `tmp_ajoccpt_racer_sets`（category_code='CL1'）に全国版ランキングが存在し、
    順位ライン判定は ME 系の WHERE パターンをそのまま流用できる
  - ランキングは出走者のみに順位が付くため、「rank<=80」判定は無出走者を自動的に降格対象へ
    含める（Requirement 2.4 と整合）。ただし検証段階では従来の出走判定
    （CL1+UCIWE, status<>0）を照合用クエリとして残し、ランキング不在＝無出走の対応を
    目視確認する（UCIWE 取りこぼし再発防止、Requirement 8.3）
- **Implications**: WE1 判定は ME 型（順位ライン）へ移行。出走判定クエリは検証用として保持

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| A: 既存パターン拡張（採用） | アプリ側はシーズン分岐＋ルール配列の追加、SQL 側は既存資産の 2 段化改訂 | 過去シーズン非影響が構造的に保証される。検証済み資産の再利用。期限内完了が現実的 | ルール値が PHP と SQL の 2 箇所に分散（層が異なるため不可避） | 値の所在は Requirement 6.4 のコメント/ドキュメントで相互参照 |
| B: ルール値の DB パラメータテーブル化 | 昇格枠・残留ラインを DB テーブルで管理 | 値変更が SQL の UPDATE で済む | スキーマ変更・管理画面・既存分岐の全面書換えが必要。期限リスク大 | 却下（agreement-log 参照） |
| C: シーズン末判定の Shell（アプリコード）化 | 降格判定を CakePHP Shell として実装 | テスト容易性向上 | 検証済み SQL 資産の作り直し。年1回実行に対し過剰 | 却下（agreement-log 参照） |

## Design Decisions

### Decision: リアルタイム昇格枠の切替方式
- **Context**: MM2→MM1 の上限を 2026-27 から 3 名にし、過去シーズンへ影響させない
- **Alternatives Considered**:
  1. 既存 24-25 分岐の CM2 ルールを書き換える — 過去シーズンの再計算結果が変わるため不可
  2. 新シーズン判定 `_isSeasonAfterEq2627()` ＋ 新分岐を最上位に追加 — 既存パターン準拠
- **Selected Approach**: 案2。新ルール配列（最大3名）をメンバ宣言部へ追加し、
  `__setupRankUpRules()` の最上位に 26-27 分岐を追加。26-27 分岐は 24-25 分岐の内容を
  複製し CM2 / CM2+3 のルールのみ新配列へ差し替える
- **Rationale**: 2015-16 以降 5 世代のルール切替が同方式で運用され、`__atDate`（大会開催日）
  基準の判定により再計算時も当時のルールが適用される実績がある
- **Trade-offs**: 分岐の複製によるコード重複は増えるが、シーズン間の独立性（要件1.2）が
  構造的に保証される
- **Follow-up**: 新ルール配列の出走人数閾値は AJOCC 改正文の確定値を実装タスク冒頭で確認する
  （上限 3 名は確定。人数区分の刻みは公式文書と照合）

### Decision: 系統横断判定 SQL の 2 段構成
- **Context**: Requirement 3〜5 の系統横断残留・ME1例外・連動降格を SQL で表現する
- **Alternatives Considered**:
  1. 既存のカテゴリー別 INSERT 文の WHERE 句へ救済条件を追記 — 各文が肥大化し目視検証不能
  2. 中間表（racer×category の自基準充足フラグ）を挟む 2 段構成
- **Selected Approach**: 案2。`survive_flags`（racer_code, category_code, meets_own,
  is_promoted）を先に構築し、有効保有ペアとの結合で救済適用済みの `demote_all` を導出する
- **Rationale**: 中間表を人間が目視・件数確認でき（Requirement 7.3）、ME1 例外・単独保有・
  対応外ペアの分岐が結合条件として明示される
- **Trade-offs**: SQL ファイルは長くなるが、各段は単純化される
- **Follow-up**: 中間表の件数・救済適用数をシミュレーション出力に含める

### Decision: 検証 SQL の「二重降格」再定義
- **Context**: 連動降格により対応ペア 2 カテゴリーの同時降格が正常系になる
- **Selected Approach**: `03_verify.sql` の重複検出を「同一系統内（ME 同士 / MM 同士）での
  複数降格 = 0 期待」と「対応外ペアの同時降格 = 0 期待」に分割し、対応ペアの同時降格は
  「連動降格件数」として正常系の集計に出力する
- **Rationale**: 異常検知の網羅性を保ちつつ新ルールの正常系を検証項目へ昇格させる
- **Trade-offs**: なし（検証の精緻化のみ）

### Decision: 対応表の SQL 内複製の扱い
- **Context**: 対応表の単一ソースは me-mm-linkage の `CategoryLineageMap`（PHP）だが、
  SQL からは参照できない
- **Selected Approach**: SQL 内の対応ペア定義（C2⇔CM1, C3⇔CM2, C1→CM1 非対称、降格先
  マッピング）には `CategoryLineageMap` を出典とするコメントを必ず付し、runbook の
  「次年度の更新点」に対応表変更時の追随チェックを追加する
- **Rationale**: 重複定義禁止の原則（roadmap Shared seams）に対する、層の違いによる
  やむを得ない複製を「出典明記＋更新チェックリスト化」で管理する
- **Follow-up**: me-mm-linkage の対応表定義が変更された場合は本 spec の SQL を再検証する
  （design.md Revalidation Triggers に記載）

## Risks & Mitigations
- 新ルール配列の人数閾値の誤読 — AJOCC 公式改正文との照合を実装タスクの冒頭手順とし、
  確定値を agreement-log へ追記する
- me-mm-linkage 未完了時のテスト基盤不在 — 本 spec のアプリ側テストは Fixture を
  自前定義できる構成とし、me-mm-linkage の Fixture が先にあれば再利用する（Wave 順に依存しない）
- 2025-26 データでのシミュレーションは新ルールの「正解」が存在しない — 旧ルール実績
  （583名）との差分を要因別（ライン変更・横断救済・WE1新基準）に説明できる集計を出力し、
  境界ケースを公開ランキングと突合して妥当性を確認する
- 是正バッチ（catracer-cleanup-2026-27）未実施データでの検証 — 対応外ペア保有者は
  「個別判定」（Requirement 3.4）に落ちるため判定自体は破綻しない。検証時に対応外ペア
  保有者数を出力し、是正後の再実行要否を判断する

## References
- [AJOCC 2026-2027 ルール改正](https://www.cyclocross.jp/news/2026/07/20262027amendment.html) — 改正内容の一次ソース
- `.kiro/specs/me-mm-linkage-2026-27/design.md` — ME⇔MM 対応表・両保有モデルの単一ソース定義（upstream）
- `docs/specs/rider-demotion-2025-26/runbook.md` および `sql/` — 改訂ベースとなる 2025-26 資産
- `cyclox2_svr/cyclox2/app/Controller/Component/ResultParamCalcComponent.php` — リアルタイム昇格の既存実装
- `.kiro/steering/roadmap.md` — プロジェクト全体方針・Shared seams
