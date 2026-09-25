# テスト結果記録: me-mm-linkage-2026-27 第3版（＋entry-auto-category-2026-27 第6版）

| 項目 | 内容 |
|---|---|
| 対象 | 第3版 改訂タスク S1〜S6、entry-auto-category-2026-27 タスク E1 |
| 実行日 | 2026-09-25 |
| 実行者 | Claude Code |
| 対象ブランチ | cyclox2web `fix/me1-holder-linkage-2026-27`（origin/main `eaefadb` から分岐、未コミット） |
| テストフレームワーク | PHPUnit 3.7.38（CakePHP 2.10.24 組込みテストランナー経由） |
| 実行環境 | Docker。`kyamady/img_cyclox2_svr` イメージの使い捨てコンテナに、本worktreeのsubmoduleをマウントして実行。テストDBは専用スキーマ `cyclox2_test_me1`（`cyclox2_mysql` 上） |
| 実行コマンド | `docker run --rm --network cyclox2_docker_fixed_compose_network -v <worktree>/cyclox2_svr/cyclox2:/var/www/html -v <database.php(test=cyclox2_test_me1)>:/var/www/html/app/Config/database.php:ro -v <tmp>:/var/www/html/app/tmp -v <main>/cyclox2_svr/cyclox2/vendors/phpunit.phar:/var/www/html/vendors/phpunit.phar:ro --entrypoint bash kyamady/img_cyclox2_svr -c "cd /var/www/html/app && ../lib/Cake/Console/cake test app <対象パス>"` |

**実行環境についての注記**: 常駐コンテナ `cyclox2_svr` はメインチェックアウトのsubmoduleをマウントしているため、
worktreeの変更をテストするには別コンテナが必要だった。また、当初は共有のテストDB `cyclox2_test` を
使っていたが、同時刻に別の実行（常駐コンテナ `cyclox2_svr` から）が同じDBでテストを走らせており、
`Table 'cyclox2_test.meets' doesn't exist` / `Duplicate entry` のエラーが断続的に発生した（`SHOW PROCESSLIST`
で相手の `TRUNCATE TABLE cyclox2_test.categories` を確認）。コードの問題ではないため、専用スキーマ
`cyclox2_test_me1` を作成して以降の実行をすべてそちらで行った（以下の結果はすべて専用スキーマでの値）。

---

## 回帰確認（関連14スイート）

| スイート | 変更前（ベースライン） | 変更後 |
|---|---|---|
| `Console/Command/CatRacerCleanupShell` | OK 48 / 267 | OK 48 / 267 |
| `Controller/ApiController` | OK 9 / 37 | OK 9 / 37 |
| `Controller/CategoryRacersController` | OK 11 / 51 | OK 11 / 51 |
| `Controller/Component/ResultParamCalcComponent` | OK 30 / 184 | OK 32 / 192 |
| `Controller/EntryRacersController` | OK 10 / 35 | OK 10 / 35 |
| `Controller/OrgUtilController` | OK 6 / 41 | OK 6 / 41 |
| `Cyclox/Const/CategoryLineageMap` | OK 11 / 58 | OK 13 / 71 |
| `Cyclox/Util/CatRacerCleanupJudge` | OK 31 / 150 | OK 31 / 150 |
| `Cyclox/Util/CategoryLineageLinker` | OK 85 / 226 | OK 86 / 270 |
| `Integration/EntryAutoCategoryIntegration` | OK 5 / 29 | OK 6 / 33 |
| `Integration/MeMmLinkageIntegration` | OK 7 / 66 | OK 7 / 68 |
| `Model/CategoryRacerFixtureData` | OK 8 / 19 | OK 8 / 19 |
| `Model/CategoryRacer` | OK 16 / 77 | OK 18 / 86 |
| `Model/EntryRacer` | OK 19 / 58 | OK 19 / 58 |
| **合計** | **296 テスト** | **304 テスト、全GREEN** |

（表記は「テスト数 / アサーション数」。ベースラインは共有DB `cyclox2_test` での実行値で、その時点では競合は発生していなかった）

### 新仕様に合わせて期待値を変えた既存テスト

| テスト | 変更内容 | 根拠 |
|---|---|---|
| `CategoryLineageLinkerTest` の `isFormerElite1()` 系6本 | `holdsElite1AsOf()` 系5本に置換（終了済みC1は保有者ではない、等） | Req 5.1 |
| `CategoryLineageLinkerTest` の `resolveLinkedTarget()` 系8本 | 削除（メソッド削除。対応表は `CategoryLineageMapTest` で担保） | design 第3版 |
| `...AppliesFormerElite1SpecialCaseEndToEnd` | 過去にC1を持つ選手のエリート側はC2のまま、に反転 | Req 4.3, 5.3 |
| `...DoesNotDuplicateHoldPointsOnFormerElite1EndToEndUpdate` | 連動しない場合も保持ポイントが変化しないこと、に変更（連動する場合は既存の(f)が担保） | Req 4.5 |
| `testSupplementAppliesFormerElite1SpecialCaseGrantingC1InsteadOfC2` | C2が付与されC1は付与されない、に反転 | entry Req 2.2 |
| `ResultParamCalcComponentTest::testMastersCm2ToCm1PropagatesEliteToC1ForFormerMe1` | エリート側はC2、に反転 | Req 4.3 |
| `CategoryRacerTest::testFormerElite1WithActiveCm1ProducesNoWarning` | 手動（LANKUP以外）C1付与で警告が出る、に反転＋2本追加 | Req 5.4 |
| `CategoryRacerTest` / `CategoryRacersControllerTest` の警告文言 | 「ME1（C1）を保有していなかった選手に…」 | design 第3版 |
| `MeMmLinkageIntegrationTest::testPreExistingSameLineageMultipleStillCompletesWithWarning` | C4＋CM1＋CM3でC4→C3昇格時、CM2を作らずCM1・CM3を残す、に変更 | Req 4.9（最上位CM1が連動先CM2より上位） |

## ミューテーション確認

判定ロジックを一時的に壊し、追加・変更したテストが失敗することを確認した（すべて元に戻したことを `cmp` で確認済み）。

| # | 壊し方 | 検知したテスト |
|---|---|---|
| M1 | 非降格の比較を無効化（上位保有でも連動する） | Linker 4件（C1保持、C2非降格、CM1非降格、複数行で最上位が上位） |
| M2 | 最上位ではなく最下位の行を比較・cancel対象にする | Linker 2件（複数行のケース） |
| M3 | ME1保有者の補完不要分岐を削除 | Linker 3件（C1＋CM1、C1のみ、C1＋CM3） |
| M4 | CM1種目の補完付与先をC1に戻す（本番事象の再現） | Linker 3件、`EntryAutoCategoryIntegrationTest`（API経路の回帰テスト）1件 |
| M5 | ME1保有判定を過去の保有歴ベースに戻す（cancel_date条件を無効化） | Linker 1件、CategoryRacer 1件 |
| M6 | C1以外の行の保存でもME1警告の判定を行う | CategoryRacer 1件（ME1保有者へのCM1付与） |
| M7 | CM1への昇格連動の連動先をC1へ引き上げる（リアルタイム昇格側の旧挙動） | Linker 8件、ResultParamCalcComponent 4件 |

## ログ出力の確認（S5）

`NO_PROPAGATION_HIGHER_HELD` のINFOログは、テスト実行時のログファイルで実際の出力を確認した（ログ内容をアサーションするテストは既存に前例がないため追加していない）。

```
Info: 系統間連動（エリート側の追随更新）は、連動先より上位のカテゴリーを保有しているため行いませんでした。racer_code:TCR31 linked_category_code:C2 held_category_code:C1
Info: 系統間連動（エリート側の追随更新）は、連動先より上位のカテゴリーを保有しているため行いませんでした。racer_code:TCR32 linked_category_code:C3 held_category_code:C2
```

## 独立検証（tester サブエージェント、2026-09-25）

判定: **PASS-WITH-NOTES**。14スイートを tester 自身が専用スキーマで実行し、全304テストGREENを確認。
判定表（me-mm 第3版の8行、entry 第6版のC1を含む3行）と Requirement 5.4 の各分岐に対応するテストの存在を確認。

| 指摘 | 対応 |
|---|---|
| (A) `__execApplyRankUp()` 側の `NO_PROPAGATION_HIGHER_HELD` ログ分岐を通るテストが `ResultParamCalcComponentTest` に無い | 同分岐は `MeMmLinkageIntegrationTest::testPreExistingSameLineageMultipleStillCompletesWithWarning`（C4＋CM1＋CM3 の C4→C3 昇格）で実行されている。分岐内に例外を注入するミューテーションで同テストがErrorになることを確認（元に戻したことを `cmp` で確認）。テスト追加は不要と判断 |
| (B) エリート側に「未来日で発効するC1」だけを持つ選手がCM種目へエントリーすると、ME1保有者分岐（`apply_date` 下限なしの保有確認を流用）により補完不要（ログのみ）になる | 既知の境界ケースとして受容。この場合も付与は行われず（ME1保有者分岐が無くても `SKIPPED_ALREADY_OCCUPIED` で付与なし）、違いは通知がログのみか警告配信かだけ。未来日で片側だけのカテゴリーが登録される運用は実質存在しないことを確認済み（entry-auto-category-2026-27 決定事項#9）。コード変更なし |
| (C) 合計テスト数の誤記 | 修正済み（変更後304、ベースライン296） |

## 独立レビュー（reviewer サブエージェント、2026-09-25）

判定: **APPROVED**（ブロッキングなし）。本番バグの根本原因（CM1→C1の引き上げ）はエントリー補完・リアルタイム
昇格の両経路から除去済み。判定表8行をコード追跡で確認、テストの弱体化なし、`MeMmLinkageIntegrationTest`の
期待値変更はReq 4.9と一致。

| 指摘 | 内容 | 対応 |
|---|---|---|
| MODERATE-1 | 手動C1警告の判定日を「保存行のapply_date」にしているため、終了済みC1行の再有効化（cancel_dateを空に戻す編集）や、過去日付でのC1新規付与では、過去の保有期間が根拠になり警告が出ない | **2026-09-25 人間判断: 後続タスクに先送り**（今回のPRには含めない。警告表示の精度の問題でデータは壊れないため） |
| MINOR-1 | 既存C1行のapply_dateを前倒しする編集で、誤って警告が出る（MODERATE-1と同根） | MODERATE-1と同じ後続タスクで扱う |
| MINOR-2 | helper名がdesign/tasksと不一致 | tasks.md実装メモに記録済み |
| MINOR-3 | 同順位の重複行の選択（idの小さい行）が仕様・テストに無い | tasks.md実装メモに記録済み。有効集合は変わらないため追加対応なし |
| MINOR-4 | ME1保有者分岐が開催日より後に発効するC1も含める | testerの指摘(B)で受容済み |

## lineage-propagation-idempotency-2026-27（cyclox2web PR #32）との統合後（2026-09-25）

PR #31 作成後に main へマージされた PR #32 とコンフリクトしたため、origin/main をマージして統合した
（統合方針は design.md「lineage-propagation-idempotency-2026-27 との統合」）。マージコミット `d416a5a`。

| スイート | 統合後 |
|---|---|
| `Console/Command/CatRacerCleanupShell` | OK 48 / 267 |
| `Controller/ApiController` | OK 9 / 37 |
| `Controller/CategoryRacersController` | OK 11 / 51 |
| `Controller/Component/ResultParamCalcComponent` | OK 34 / 204 |
| `Controller/EntryRacersController` | OK 10 / 35 |
| `Controller/OrgUtilController` | OK 6 / 41 |
| `Cyclox/Const/CategoryLineageMap` | OK 13 / 71 |
| `Cyclox/Util/CatRacerCleanupJudge` | OK 31 / 150 |
| `Cyclox/Util/CategoryLineageLinker` | OK 96 / 327 |
| `Integration/EntryAutoCategoryIntegration` | OK 6 / 33 |
| `Integration/MeMmLinkageIntegration` | OK 7 / 68 |
| `Model/CategoryRacerFixtureData` | OK 8 / 19 |
| `Model/CategoryRacer` | OK 18 / 86 |
| `Model/EntryRacer` | OK 19 / 58 |
| **合計** | **316 テスト、全GREEN** |

統合後のミューテーション確認（Linkerスイート）:

| 壊し方 | 結果 |
|---|---|
| 非降格の比較を無効化 | 5件失敗 |
| 最上位の判定を反転 | 4件失敗 |
| CM1への昇格連動の連動先をC1に戻す | 16件失敗 |
| 非降格の比較対象を現在有効な行だけに戻す（統合で決めた判定） | 追加テスト `testPropagateDoesNothingWhenFutureDatedHoldingIsHigherThanTarget` が失敗 |

**実行環境の注記**: 統合の検証中に、ローカルの `cyclox2_mysql` コンテナがメモリ不足で強制終了（OOMKilled）した。
前回の異常終了で残っていた `mysql.sock` / `mysql.sock.lock` が起動スクリプトの `chown` を失敗させて再起動できなかったため、
この2ファイルと古い pid ファイルを削除して再起動した（InnoDB のクラッシュリカバリは正常終了、`cyclox2` DB は無事）。
以降はテスト用コンテナのメモリを `--memory=1g` に制限し、スイートを1つずつ実行した。専用スキーマは `cyclox2_test_me1merge`。
