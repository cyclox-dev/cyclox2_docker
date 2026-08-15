# 合意ログ: tohoku-series-2026-27

タスクID: `tohoku-series-2026-27`
作成日: 2026-08-15

## 壁打ち段階での合意事項（2026-08-15）

| # | 論点 | 合意内容 | 根拠・補足 |
|---|---|---|---|
| 1 | 配点基準 | 26-27 新AJOCC得点表の **出走人数8区分表**（非JCX列）を使用する | `TCX_223` / `TCX_245` が「その年度の AJOCC ポイント表を流用し、JCXテーブルは使わない」方針で実装されてきた運用の踏襲。`AJOCC_267`（`val=13`）は JCX列を使うため東北シリーズには不適 |
| 2 | 実装方式 | `PointCalculator` に `TCX_267`（`val=14`）を新規追加する | オープン中の他ブランチ（PR #13 / #15）は `PointCalculator.php` を変更していないため採番衝突なし（調査で確認） |
| 3 | 起点ブランチ | `release/2026-27-season-rules` を起点とする | 当初ユーザー回答は `feat/ajocc-point-267-prod` 起点だったが、同ブランチは PR #14 で release へマージ済みであり、release 起点の方が最新かつ同一内容であることを説明し合意 |
| 4 | リリース単位 | `release/2026-27-season-rules` → `main` の **先行リリース**に、`ajocc-point-267-prod` と本仕様の両方を含める | 調査により release ブランチの main 差分が 267prod のみ（PR #13/#15 未マージ）であることを確認。追加の切り分け作業なしで「新得点表と東北シリーズの同時本番反映」というユーザー要望が成立する |
| 5 | 結合試験 | `ajocc-point-267-prod` の未消化17項目を、東北シリーズ分とセットで先行リリース前に実施する | 267prod は実装・単体テスト完了済みだが `integration-test-checklist.md` が全項目未チェック・確認者空欄であることを確認 |
| 6 | 集計ルール | `sum_up_rule=2` / `point_term_rule=1` / `point_to=1` を踏襲。変更は `calc_rule` のみ | 開発環境DB調査により、東北シリーズは 2017-18 以降これらの値が一貫していることを確認 |
| 7 | シリーズ登録 | コード対象外。runbook として手順のみ残し、リリース後にユーザーが管理画面で実施 | 過去の東北シリーズ実装（PR #9 等）もコード変更は `PointCalculator.php` のみだった |
| 8 | シリーズ構成 | 現段階では確定しない。runbook はカテゴリー数非依存で記述する | 「レース構成は大会運営中に主催者が検討して決定する」というユーザー判断。`TCX_267` はカテゴリー非依存のためコードに影響しない |
| 9 | 進め方 | グローバル規定（構成C）を採用。Tier 2（`calc_rule` 新値追加＝公開インターフェース相当）。spec 作成は軽量モードで実装直前まで一気に進め、実装着手前に人間承認を得る | ユーザー指示 |

## 調査で確定した事実（2026-08-15）

- `point_series_groups` に「東北」（`id=2`, `priority_value=35`）が既存 → 新規作成不要
- `seasons` に 2026-27（`id=17`, 2026-09-01〜2027-03-31）が既存 → 新規作成不要
- 東北シリーズの `calc_rule` 変遷: `THK_178`(7) → `KNT_178`(6) → `TCX_223`(9) → `TCX_245`(12)
- 25-26 は新テーブルを作らず `TCX_245`(12) を流用（AJOCC得点表が 24-25 と同一だったため）。
  26-27 は得点表が改正されるため新規計算器が必要という判断はこの運用と整合
- 26-27 非JCX表は8区分。要素数 119/99/79/59/39/19/9/4、1位配点 400/400/400/350/300/250/200/200
  （`ResultParamCalcComponent` から機械的に抽出して確認）
- 25-26 東北シリーズは12本（ME1/WE1/MM1/CK1/CK2/CK3 は res-sys 公開、
  ME2/ME3/ME4/WE2/MM2/MM3 は非公開）、各シリーズ5大会（MM1 のみ3大会）

## 設計上の判断

| # | 判断 | 内容 |
|---|---|---|
| D1 | 得点表の二重定義 | System①（`ResultParamCalcComponent`）と System②（`PointCalculator`）に同じ数値を持つことになるが、共通定数化はせず**独立定義＋等価性テスト**で担保する。共通化は Requirement 4.4（System① 無変更）に反し、検証済みコードへ回帰リスクを持ち込むため。共通化は 4 spec 完了後のリファクタリング候補として申し送る |
| D2 | シリーズ登録の扱い | マイグレーション化せず runbook 化。シリーズ構成が未確定であり、コードに固定すべきでないため |

## 承認状態

| フェーズ | 生成 | 承認 | 備考 |
|---|---|---|---|
| requirements | 済 | **未** | 実装着手前の一括承認を待つ |
| design | 済 | **未** | 同上 |
| tasks | 済 | **未** | 同上 |

> ユーザー指示により、requirements / design / tasks を軽量モードで一括生成し、
> **実装着手の直前で一度だけ人間承認を求める**運用としている。承認が得られた時点で
> `spec.json` の approvals を `true` に更新し、`ready_for_implementation` を `true` にする。

## 独立レビュー記録（2026-08-16）

`reviewer` サブエージェント（独立コンテキスト・read-only）による敵対的レビューを実施。
実コード・実DB・実ブランチに当たって spec の各主張の反証を試行させた。判定は **NEEDS REWORK**。

### 反証を試みたが成立した主張（10件）

`val=14` の採番安全性、`AJOCC_267_TEST`→`AJOCC_267` リネームの低リスク性、8区分の数値
（要素数 119/99/79/59/39/19/9/4、1位配点 400/400/400/350/300/250/200/200）、境界演算子と
`isset` の等価性、**前例（`KNT_178` / `TCX_223` / `TCX_245` がいずれも当該年度の AJOCC 非JCX表と
一致）**、スキーマ（`calc_rule` は `smallint unsigned`）、View/Controller 変更不要、DB調査結果、
2026-09-01 日付ゲートの安全性（4〜8月開催の大会は全期間0件）、release と main の差分。

最重要の判断（8区分非JCX表を使う）は前例と一致しており**正しい**ことが実表の突き合わせで確認された。

### 指摘を受けて改訂した点

| # | 指摘 | 改訂内容 |
|---|---|---|
| H2 | Req 3.2「範囲外→ポイント0」が公開API挙動と不一致。`calc()` 末尾の `if (empty($pt['point']) && empty($pt['bonus'])) return null;` により**0点は `null` として観測される**。全2000ペア中1146ペア（57%）が該当 | Req 3.2 を `null` に修正し Req 3.4（`point_series_racers` 行が作られない）を追加。design の Error Handling 表を戻り値2段階の表に改訂。tasks 2.2 の期待値を修正 |
| H1 | 等価性テストは `calcAjoccPt()` の `ajoccPtMap` 永続キャッシュで必ず破綻する。起点ブランチではキャッシュ破棄メソッドが 267prod により削除済み | tasks 2.3 に「出走人数ごとに新規インスタンス（16個）／順位ループは使い回し」「戻り値の null→0 正規化」を明記 |
| H3 | `PointCalculator` は `__resetSeriesPoints()` からのみ呼ばれ、`calcUpSeries` は既存 `point_series_racers` を集計するだけ。リザルト登録済みの大会へ後から紐付けてもランキングが空になる | Req 5.7 を追加。design の System Flows を前段（付与）／後段（集計）の2図に分割して実経路を明示 |
| H4 | 親リポジトリ `main` の submodule ポインタ（`2479bcd`）は `feat/jcx-lineage-lock-2026-27` の未マージコミットを指しており、結合試験がリリース対象でないビルドを検証してしまう | Req 6.4 を追加。design に「submodule ポインタの取り扱い」節を追加。tasks 5.3（結合試験実施）にチェックアウト手順を追加 |
| M4 | 未実装時 `getCalculator(14)` が `null` を返すため、RED が assertion failure でなく Fatal になりスイートが中断する | tasks 2.1 に `assertNotNull` を先頭に置く旨を明記 |
| M5 | tasks 4.1 の `AJOCC_267` 回帰テストは既存テストと重複（同名追加は Fatal） | tasks 4.1 を「既存6テストは GREEN 確認に留め、新規は `TCX_245` 回帰と件数検証のみ」に修正 |
| M6 | Req 6.3（結合試験の実施・記録）を実行するタスクが無かった | tasks 5.3 を新設（旧 5.3 は 5.4 へ繰り下げ） |
| M1 | design の図が PR #15 の base を release としていたが、実際は `feat/me-mm-linkage-2026-27`（stacked PR） | design に注記を追加 |
| M2 | release→main のマージ方式が未指定。squash/rebase だと release 再利用時に履歴が乖離 | Req 6.5（`--no-ff` 必須）を追加 |
| M3 | `PointSeries/view.ctp:39` 等が `getCalculator()->name()` を null チェックなしで呼ぶため、`calc_rule=14` の行がある状態で `main` へロールバックすると Fatal | design に「ロールバック時の既知の危険」節を追加。tasks 5.4 で PR 本文への明記を要求 |
| M7 | runbook 要件の欠落（26-27 の `meets` が0件、`meet_point_series` の必須項目 `express_in_series` 等） | Req 5.5 / 5.6 / 5.8 を追加・拡充 |
| L1 | `$text` 生成で `TCX_245` 書式（`% 10 == 0` のみ）を使うと、8区分の要素数がいずれも10の倍数でないため区分末尾で改行されず表示が崩れる | design / tasks 3.1 で `KNT_178` の書式（`|| $j == $n - 1`）採用を明示 |
| L2, L3 | description/text の要求文言が曖昧、Req 1.5 の検証タスクが無い | tasks 2.1 で要求文言を分離し、全8区分見出しの検証を追加 |

### レビュー結果の検証で判明した追加事実（レビュアーの指摘に含まれない自己発見）

**ローカルの `release/2026-27-season-rules` は `origin/main` と同一の古い状態（`2c3fd3a`）であり、
`origin/release/2026-27-season-rules`（`0635466`）とは別物だった。**

| ref | コミット | `val=13` の名称 | 267prod のテスト |
|---|---|---|---|
| ローカル `release/2026-27-season-rules` | `2c3fd3a` | `AJOCC_267_TEST` | 無し |
| `origin/release/2026-27-season-rules` | `0635466` | `AJOCC_267` | 有り |

古い方から分岐すると `val=13` が `AJOCC_267_TEST` のままとなり、`val=14` の前提も 267prod の
既存テストも失われる。Req 6.1 を「`origin/` 付きの ref を起点とする」に修正し、tasks 1.1 に
`git fetch origin` と分岐後の検証手順（`AJOCC_267_TEST` が見えたら分岐からやり直す）を追加した。

なおレビュアーは「`resetAjoccPtCache()` は 267prod で削除済み」と報告したが、ローカルの古い ref
では同メソッドが存在する。正しい起点 `origin/release/2026-27-season-rules` では削除済みであり、
結論（インスタンス分離が必要）は変わらない。

## 変更履歴

| 日付 | 変更内容 | 変更者 |
|---|---|---|
| 2026-08-15 | 初版作成（壁打ち合意を反映し requirements / design / tasks を一括生成） | Claude |
| 2026-08-16 | 独立レビュー（reviewer サブエージェント）の指摘13件と自己発見1件を反映し、requirements（Req 3.2 修正、3.4 / 5.5〜5.9 / 6.1・6.4〜6.6 追加）・design（Error Handling / System Flows / リリース構成 / 起点ブランチ注意 / submodule ポインタ / ロールバック危険）・tasks（1.1・2.1〜2.3・3.1・4.1 改訂、5.3 新設）を改訂 | Claude |
