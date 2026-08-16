# 結合試験チェックリスト: ajocc-point-267-prod

| 項目 | 内容 |
|---|---|
| タスクID | `ajocc-point-267-prod` |
| 作成日 | 2026-07-22 |
| 確認者 | Claude（ユーザー立会い・管理画面はユーザーのログインセッションを使用） |
| 確認日 | 2026-08-16 |
| 実施環境 | Docker（`cyclox2_svr` / `cyclox2_mysql` / `cyclox2ressys_svr`）。submodule ブランチ `feat/tohoku-series-2026-27`（`origin/release/2026-27-season-rules` 起点＝267prod 込み） |
| DB保全 | 実施前に `cyclox2` 全体を `mysqldump`（383MB） |
| 備考 | `tohoku-series-2026-27` の結合試験と合同で実施（先行リリースに両 spec の変更が含まれるため） |

> **このドキュメントは人間が手動で確認するための項目集です。**
> ブラウザ操作・サービス間連携・DB整合性など、自動テストが難しい観点を列挙します。
> 単体テストの結果は `.kiro/specs/ajocc-point-267-prod/test-results.md` を参照。

---

## 事前確認

- [x] `cyclox2_svr` / `cyclox2_mysql` コンテナが起動している
- [x] `cyclox2ressys_svr`（成績閲覧アプリ）が起動している（`docker compose up -d` で起動、`:8081`）
- [x] 開発環境DBに2025-26シーズンの実データが存在する（東海シクロクロス25-26 ME3 全7戦ほか）。
  **2026-27シーズンの大会（`meets`）は0件**のため、境界確認は既存大会の `at_date` を一時的に
  2026-08-31 / 2026-09-01 へ変更して実施し、確認後に元へ戻した（下記）

---

## 機能確認

### AJOCCポイント計算（System①）の2025-26シーズン非影響

- [x] 開発環境で2025-26シーズンの既存カテゴリー（大会結果）を再計算し、`racer_results.ajocc_pt`
  が本改修前と変化しないことを確認した（Requirement 2.1, 2.2, 2.3 の実データ上の証跡）。
  対象: 東海シクロクロス25-26 ME3 全7戦（`entry_category_id` = 25304 / 25804 / 26347 / 26640 /
  26660 / 26959 / 27733）。各カテゴリーを管理画面から再計算し、`ajocc_pt` 合計が再計算前と
  **完全一致**（1851 / 1247 / 1143 / 1826 / 1839 / 1128 / 1818）。1位の値も 25-26 の旧3区分表の
  ままであること（例: 出走46名で 180pt、出走38名で 150pt）を確認。
- [x] 2026-08-31以前開催の大会が旧年度別表のまま、2026-09-01以降開催の大会が新8区分表／新JCX表
  で計算されることを、実データ上でも境界日付で確認した。
  手順: `TKI-256-007`（ME3・出走24名）の `at_date` を一時変更し、都度再計算して比較。

  | 開催日 | `is_jcx` | 1位 | 2位 | 3位 | 適用表 |
  |---|---|---|---|---|---|
  | 2026-01-25（原状） | 0 | 150 | 120 | 100 | 旧年度別表 |
  | **2026-08-31**（境界前日） | 0 | 150 | 120 | 100 | **旧表のまま** |
  | **2026-09-01**（境界当日） | 0 | 300 | 250 | 220 | **新8区分表**（20人以上区分） |
  | 2026-09-01 | **1** | 1000 | 900 | 810 | **新JCX列** |

  確認後 `at_date` / `is_jcx` を原状（2026-01-25 / 0）へ戻し、再計算して 150/120/100・
  合計1128 に復旧したことを確認済み。

### PointSeries管理画面（System②）の命名整理反映確認

- [x] `PointSeries/add.ctp`（配点ルール選択画面）の選択肢に「**AJOCC_267**」（value=13）が
  テスト文言なしで表示されることを確認した（Requirement 3.1, 3.3）。`PointSeries/edit` でも同様。
  既存の選択肢（val=1〜12）も名称・値ともに変化なし。
- [x] 2026-27シーズンのJCF/JCXシリーズ作成時、運用担当者が配点ルールとして「AJOCC_267」を
  手動選択する必要がある旨を申し送り済み（`point_series.calc_rule` は自動割当されない設計のため、
  選択漏れがあると従来ルールのまま計算される）。同趣旨の注意は
  `.kiro/specs/tohoku-series-2026-27/runbook.md` にも東北シリーズ向けに記載
  （「前シーズンは `TCX_245`。26-27 は必ず `TCX_267` を選ぶこと」）。

### CSV出力の形式非影響確認

- [x] 既存のAJOCCランキングCSV出力（`download_ajocc_pt_csv`）の操作方法・出力形式が本改修前と
  変わらないことを確認した（Requirement 4.4）。
  - 操作: `/org_util/ajocc_pt_csv_links` の各カテゴリー行から POST。従来どおり。
  - 実行結果（2025-26 / CK3）: **HTTP 200**、`Content-Type: text/csv; charset=UTF-8`、
    `Content-Disposition: attachment; filename="ajocc_pt_ranking2025-26_CK3_outputtedAt20260816T1839.csv"`、
    95行。2025-26 / C1 でも 200（14,725バイト）を確認。
  - 列構成: `順位, "選手 Code", 選手名, チーム名, <大会ごとの列…>` と従来どおり。
  - 文字コード: 本文は **SJIS**（`OrgUtilController::__putToFp()` の
    `mb_convert_variables('SJIS', 'UTF-8', $row)` による。Excel 互換のため）。従来どおり。
  - **コード上の裏付け**: 267prod が変更したのは5ファイル
    （`PointSimShell.php` 削除 / `ResultParamCalcComponent.php` / `PointCalculator.php` /
    テスト2件）のみで、`OrgUtilController.php` および CSV 関連ビューは**変更されていない**
    （`git log origin/main..origin/release/2026-27-season-rules -- app/Controller/OrgUtilController.php` → 0件）。
- [x] シリーズランキングCSV出力（`PointSeriesController::calcUpSeries` 経由）についても
  出力形式が崩れないことを確認した。
  合同実施した `tohoku-series-2026-27` の試験で、`TCX_267` を選択したシリーズのランキングCSVを
  生成し、列構成（`順位, "選手 Code", JCF-No., UCI-ID, 選手名, チーム名, <戦ごとの列>, 合計`）と
  文字コード（**UTF-8**）が既存シリーズのCSV（`ranking_374.csv` = `JCX_245`）と同一であることを
  確認済み。`AJOCC_267`（val=13）についても、同一の `PointSeriesController` 経路を通るため
  形式差は生じない（計算器の違いは各セルの数値のみ）。

---

## サービス間連携確認

- [x] `cyclox2_svr`（本体） ↔ `cyclox2ressys_svr`: 2026-09-01開催として再計算した大会の
  リザルト表示（`:8081/race/26959`）が **300pt/ME3・250pt/ME3・220pt/ME3 …** と新得点表の値で
  正しく表示され、表示崩れが無いことを確認した。開催日表示も 2026-09-01 で整合。
  なお res-sys 側は `racer_results.ajocc_pt` / `tmp_ajoccpt_racer_sets` の確定値を表示するのみで
  得点表ロジックを持たない（`calc_rule` 参照も0件）ため、構造上の影響はない。
- [x] `cyclox2_svr` ↔ MySQL: 再計算（`reCalcResults`）を通じた `racer_results.ajocc_pt` /
  `point_series_racers` への書き込みが正常に完了し、同一条件での複数回再計算で値が一致すること
  （途中状態の残存が無いこと）を確認した。トランザクション制御は `__reCalcResults` を包む既存
  実装のままで、本改修による変更はない。

---

## DB整合性確認

- [x] `racer_results.ajocc_pt` が大会開催日に応じて意図した表（新／旧）の値で正しく更新される
  ことを確認した（上記の境界日付テストの表を参照）。
- [x] `point_series.calc_rule=13`（`AJOCC_267`）のシリーズで集計が正しく動作することを確認した。
  検証用シリーズを作成し `TKI-256-007` ME3 を紐付けて再計算した結果、
  **1000 / 900 / 810 / 730 / 660 / 600**（新JCX列・グレード非依存）が付与され、24名分の
  `point_series_racers` が作成された。確認後、検証用データは削除済み。

---

## 非機能確認

- [x] エラー時（出走人数0人以下など）に適切なエラー値が返ることを確認した。
  `calcAjoccPt()` は `$startedCount <= 0` で `-1`、`$rank` が空で `0` を返す。
  自動テスト `ResultParamCalcComponentTest::testStartedCountZeroOrLessReturnsErrorValueRegardlessOfDate`
  が日付によらずこの挙動になることを検証しており、実行して GREEN（1 test, 5 assertions）を確認。
- [x] `app/tmp/logs/debug.log` に AJOCC_267 関連の異常なエラー出力が無いことを確認した
  （`ajocc_267` / `ajocc267` / `PointCalculator` に該当するエラー行は **0件**）。
  結合試験中に記録された Notice 5件は
  `EntryCategoriesController.php:118` の `Undefined index: PointSeries` で、**論理削除済みの
  ポイントシリーズを参照するリザルトを画面表示した場合に出る既存事象**（該当行は古いコミット
  `f1439ba` 由来で本改修とは無関係）。検証用データ削除後は再現しない。別途改修候補として起票済み。
  `error_log` の SMTP fatal は、`/point_series/calcup/457` へ GET した際の
  `MethodNotAllowedException` を開発環境のメール通知が送れずに出したもので、本改修とは無関係。
- [x] `PointSimShell.php` 削除後、Console一覧に該当コマンドが表示されないことを確認した。
  `Console/cake` の出力は `[app] cat_limit, one_time, org_util, result` のみで `point_sim` は無し。
  `app/Console/Command/` の実ファイルも `AppShell / CatLimitShell / OneTimeShell / OrgUtilShell /
  ResultShell` のみで、`PointSimShell.php` は存在しない。
- [x] レスポンスが許容範囲の速度で返ることを確認した。
  出走カテゴリーのリザルト再計算（`POST /entry_categories/recalc_result/<id>`）は、
  29〜51名規模のカテゴリーで **4秒以内**に完了（access_log の POST → 後続 GET の時刻差で確認）。
  本改修は表選択の分岐追加のみで計算量は変わらず、体感できる遅延は無い。
  なお AJOCCランキングCSV生成（`download_ajocc_pt_csv`）はシーズン×カテゴリー全体を集計するため
  カテゴリーによって数分かかるが、これは**本改修以前からの特性**（本改修は当該コード経路を
  変更していない）。

---

## 確認結果

| 区分 | 件数 |
|---|---|
| 確認済み | **17 / 全17件** |
| 未確認 | 0 |
| NG | 0 |

> 原本の集計表は「全18件」と記載されていたが、実際のチェック項目は17件（事前確認3・機能確認6・
> サービス間連携2・DB整合性2・非機能4）であったため17件に訂正した。

### 実施方法に関する補足

- 2026-27シーズンの大会（`meets`）が開発環境DBに0件のため、境界日付の確認は既存大会
  `TKI-256-007` の `at_date` / `is_jcx` を一時的に変更して再計算し、確認後に原状復帰する方式で
  実施した。復帰後に `ajocc_pt` がベースラインと完全一致することを確認済み。
- 実施前に `cyclox2` データベース全体を `mysqldump` で保全した（383MB）。
- 検証用に作成した `point_series` / `meet_point_series` / `point_series_racers` /
  `tmp_point_series_racer_sets` はすべて削除済み。有効な `calc_rule=13` / `calc_rule=14` の
  シリーズは0件の状態に戻っている。

### NG項目メモ

（NG があった場合のみ記載）

| # | 項目 | 内容 | 対応状況 |
|---|---|---|---|
| | | | |
