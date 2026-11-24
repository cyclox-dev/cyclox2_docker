# Research & Design Decisions

## Summary
- **Feature**: `uciwj-wj-ranking-fix-2026-11`
- **Discovery Scope**: Simple Addition（マスタ1行の追加と本番データ是正。アプリのコード変更なし）
- **Key Findings**:
  - 成績対象カテゴリー（`racer_results.as_category`）は取込時に1回だけ決まり、決め方は `category_races_categories` の対応で決まる。対応を1行足せば、以後の取込（管理画面アップロード・アプリAPIの両経路）は自動で WJ になる。
  - AJOCC ポイント値の計算（`calcAjoccPt`）は as_category を参照しない。as_category を直してもポイント値は変わらない。
  - 本番のランキング更新バッチは毎時動作しており（フラグ処理済み時刻 21:31, 22:30 等）、更新フラグを1行入れれば通常の流れで全国版＋地域版の WJ ランキングが再生成される。公開サイト（ressys）の DB は本番とほぼ同時刻の内容に追随している。

## Research Log

### as_category の決まり方と参照箇所
- **Sources**: `ResultParamCalcComponent::__asCategory()`（cyclox2web `app/Controller/Component/ResultParamCalcComponent.php` 1861行〜）、`ResultReadComponent::__makeAsCategory()`、`ApiController`（712行付近）
- **Findings**:
  - 種目に紐づくカテゴリーが1件なら、選手の保有に関係なくそのカテゴリー（`isSingleCat`）。0件なら種目コードそのもの。複数件なら保有している中で上位。
  - 対応を `UCIWJ → WJ` の1件で追加すれば、UCIWJ 種目の全成績が WJ になる（UCIMJ → CJ と同じ形）。
  - as_category の参照箇所: ランキング生成 `ResultShell::updateAjoccPtRankings`（as_category 単位でランキング更新・Category に無い値はスキップ）、集計 `__updateAjoccRanking` / `OrgUtilController`（`as_category != catCode` を除外）、`CatRacerCleanupJudge`（elite/masters 判定。`UCIWJ`・`WJ` はどちらも判定不能＝null で挙動同一）、画面表示（`ajocc_pt/as_category`）。
  - 「リザルトを再計算する」（`reCalcResults`）は ajocc_pt 等を再計算するが as_category は書き換えない。
- **Implications**: マスタ追加＋既存6件の as_category 直接更新で足りる。アプリのコード変更は不要。

### ランキング更新の流れと公開サイトへの反映
- **Sources**: `ResultShell.php`（updateAjoccPtRankings / updateAjoccRanking）、本番 `tmp_result_update_flags` / `tmp_ajoccpt_racer_sets` の時刻、ressys 本番 DB
- **Findings**:
  - バッチは `tmp_result_update_flags` の `ajoccpt_sumuped = 0` かつ `applies_ajocc_pt = 1` の出走カテゴリーを拾い、その出走カテゴリーの as_category（DISTINCT）ごとに、当該シーズンの全国版と全地域版設定のランキングを作り直す。
  - cron は別ユーザー設定で読めないが、フラグ処理済み時刻から毎時実行と推定（例: 21:24 生成 → 21:31 フラグ処理済み、22:24 生成 → 22:30 処理済み）。
  - ressys 本番 DB にも同名テーブル群があり、`tmp_ajoccpt_racer_sets` の WJ 行の modified（22:24:06）が本番と一致。仕組み（レプリケーション等）は権限不足で未確認だが、本番の再生成結果がそのまま公開側に現れる。
  - 手動実行用に `Console/cake result updateAjoccRanking <cat> <seasonId>` もある。
- **Implications**: 本番では cake を手で実行せず、更新フラグを入れて既存バッチに任せる（実行ユーザー・ログ権限の問題を避ける）。

### 影響データ（2026-11-24 本番ダンプ 20261124 で確認）
- 是正対象: `racer_results.id` 359429, 359430（MDX-267-002, ecat 28856）, 360444〜360447（KNS-267-013, ecat 29071）。全件 `as_category='UCIWJ'`、ajocc_pt 付与あり。6名とも大会日に WJ と CL1 を保有。
- 松伏の2件は 2026-11-24 21:39 に再取込されている（modified）。是正前に再取込されると id が変わりうる → 事前チェックで検出して停止する。
- 2026-27 の地域版設定: 26 関東（meet_group に MDX を含む → 松伏が入る）、27 もみじ、28 東海、29 四国。KNS は地域版なし。
- 対応表の既存行: 54 UCIME→C1, 55 UCIME+U→C1, 56 UCIWE→CL1, 60 UCIMJ→CJ（2018-11-26 追加）, 72 WJ→WJ。

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations |
|---|---|---|---|
| A. SQL で対応追加＋6件の as_category を直接更新＋更新フラグ投入（採用） | 変更列を as_category だけに限定し、ランキングは既存バッチで再生成 | 変更範囲が最小で件数を厳密に確認できる。ロールバックが容易 | 手で SQL を流すため承認・件数確認の手順が要る |
| B. 対応追加後に主催者がリザルトを再アップロード | 通常の取込で as_category を作り直す | SQL 直接操作が不要 | 主催者2者への依頼が要る。リザルトid・昇格・保持ポイント等も作り直され、要件2.4（他項目を変えない）を保証できない |
| C. 管理画面の RacerResults 編集で1件ずつ変更 | 画面の「成績対象カテゴリー」を変更 | SQL 不要 | フォームが全項目を保存し直すため他項目を変えないことを保証しにくい。ランキング更新フラグは立たない |
| D. 既存の OneTimeShell::setupAsCategory を流用 | as_category を再計算するシェル | 既存資産 | as_category が空の行しか処理しない。全件を offset で走査する作りで対象を絞れない |

## Design Decisions

### Decision: 是正は SQL 直接更新（選択肢A）
- **Rationale**: 要件2.4・2.5（6件の as_category 以外を変えない）を、WHERE 句（id・出走カテゴリー・現在値 UCIWJ の3条件）と件数確認で機械的に保証できるのは A だけ。
- **Trade-offs**: 本番への手動 SQL になるため、prod-access の運用ルール（事前ダンプ・1操作ごとの承認・件数照合）で統制する。

### Decision: ランキング再生成は更新フラグ投入＋既存の毎時バッチ
- **Rationale**: 通常のリザルト取込と同じ経路で再生成され、全国版・地域版の両方が作られる。本番で cake を手動実行する必要がない。
- **Detail**: フラグは `ajoccpt_sumuped = 0`、`points_sumuped = 1`（ポイントシリーズは as_category に依存しないため再計算不要）で ecat 28856・29071 に1行ずつ。バッチは1回目で WJ×2026-27 を作り直し、2行目は「処理済み」として扱う。

### Decision: ローカル検証は使い捨てコンテナ＋検証用シェル（リポジトリにはコミットしない）
- **Rationale**: 要件1.1（今後の取込で WJ になる）を、アプリの実際の判定メソッド `ResultParamCalcComponent::asCategory()` で確認するため。検証用シェルは spec 配下に置き、コンテナへのマウントでのみ使う（cyclox2web には入れない）。

## Risks & Mitigations
- 是正前に主催者が再取込し id が変わる → 事前チェックで6件の id・選手・現在値を照合、不一致なら停止（要件2.6）。マスタ追加を先に行うので、その後の再取込は自動で WJ になる。
- バッチが動かない／遅れる → 2時間経っても反映されなければ人間に報告し、手動実行（`Console/cake result updateAjoccRanking WJ 17`）を別途承認で検討。
- 誤更新 → ロールバック SQL（マスタ行の論理削除・6件を UCIWJ に戻す・フラグ再投入）と、事前ダンプで復旧可能。

## References
- `.kiro/steering/db-category-entry-glossary.md` — categories / races_categories / category_races_categories の関係
- `~/.claude/skills/prod-access/SKILL.md` — 本番アクセスの安全ルールとダンプ手順
- ユーザーメモリ `reference_worktree-cakephp-testing` — worktree で CakePHP を使い捨てコンテナで動かす手順
