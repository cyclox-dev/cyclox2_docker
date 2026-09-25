# 合意形成記録: エントリー時ME⇔MM対応ペア オンデマンド付与

| 項目 | 内容 |
|---|---|
| タスクID | `entry-auto-category-2026-27` |
| 作成日 | 2026-09-07 |
| 関係者 | kyamady（プロダクトオーナー）、Claude Code |

---

## 壁打ち概要

me-mm-linkage-2026-27（クローズ済み）で「ME⇔MM対応ペア両保有モデル」が実装されたが、対応ペアの
自動連動はレース結果による昇格時にしか発火せず、片方の系統のみを保有する選手がレース前に相手系統
でエントリーしただけでは何も起きない。主催者が「エントリー後・レース開催前」に手動で相手側
カテゴリーを付与する運用が前提になっており、シーズン中に系統を行き来する選手が多い関西シリーズ
等では主催者の恒常的な負荷になっている（発端: CCM-000-0487 上田尚徳選手の桂川MM3エントリー事例）。

対応策として「既存単独保有者（約11,210名）への一括バッチ付与（選択肢A）」と「エントリー登録を
トリガーにしたオンデマンド補完付与（選択肢B）」を判断ブリーフ
（https://claude.ai/code/artifact/1f6a3a64-e59d-4a67-ae43-837b96e544c4）で比較検討し、実データ分析
（保有状態11,778名の内訳・エントリー種目の単一/プール比率98.2%対1.8%）とコード調査（EntryRacer
モデルの保存フックが全経路を通過する単一フックである実現性の裏付け）を踏まえて選択肢Bを推奨とした。

---

## 決定事項

| # | 決定内容 | 決定理由 | 決定日 |
|---|---|---|---|
| 1 | 選択肢B（エントリー時オンデマンド付与）を主策として要件定義フェーズに進める | 選択肢Aは年齢資格チェックの欠如・ME1連鎖降格・既存不整合406名との干渉のリスクが大きい一方、選択肢Bは「相手系統の有効保有がゼロ」の選手のみを対象にするため既存不整合に干渉せず、ブラスト半径を常に1エントリー分に抑えられる | 2026-09-07 |
| 3 | プール種目（C3+4・CM2+3・CM1+2+3、全エントリーの1.8%）は本spec の対象外とする。従来どおり主催者の手動運用に委ねる | エントリー時点では系統が一意に決まらずリザルト取込時のas_category解決を待つ必要があり、対応するとフォールバック処理の新規設計が必要になりスコープが拡大する。カバー率98.2%を優先し、本specは単一カテゴリー種目への対応に絞る | 2026-09-08 |
| 2 | `me-mm-linkage-2026-27`は再オープンせず、新spec `entry-auto-category-2026-27` として独立させる | jcx-lineage-lock-2026-27・catracer-cleanup-2026-27と同じパターン（クローズ済みspecの`CategoryLineageMap`を単一の正として参照するのみ、対応表の重複定義はしない）を踏襲するため | 2026-09-07 |
| 4 | 資格年齢ガードを`propagateLinkedPromotion()`（既存・me-mm-linkage-2026-27）とcatracer-cleanup-2026-27の是正バッチにも追加する。適用対象は本specのBoundaryを拡張して取り込む（新spec化はしない） | `EntryRacer::afterSave()`まわりの動きを説明するアーティファクト作成の過程で、Web管理画面の個別CSVアップロード経路が本機能のafterSaveと昇格連動を同一トランザクション内で連続実行することが判明。年齢ガードの欠落箇所を洗い出したところ実データで既に3件の違反（35歳未満のCM1〜4保有）を確認。catracer-cleanup-2026-27は実装完了・マージ済み（PR #24）でバッティング無しと確認できたため対象に含める | 2026-09-09 |
| 5 | 新規選手CSV登録・系統切替画面（change_em）は資格年齢ガードの対象外とする | 前者は「選手登録とカテゴリー付与が一体の成功/失敗」という既存インターフェースの変更コストが大きい。後者は人間が明示的に行う特例操作を機械的に拒否するデメリットが大きい | 2026-09-09 |
| 6 | エントリー先種目の対応カテゴリーと、選手がエントリー側系統に現在保有するカテゴリーが食い違う場合は相手系統への新規付与を見送る（Requirement 11として新設） | タスク2.1実装レビューで、独立レビュアーが「エントリー先種目からのみ相手系統カテゴリーを決定し、選手の実際のエントリー側保有を見ない」ため本機能自身が新たな対応外ペアを作り出すケースを実際に実行して実証（例: CM2保有選手がCM1種目にエントリー→C2が新規付与されCM2との対応外ペアが成立）。選択肢B採用根拠（既存不整合に干渉せずブラスト半径を1エントリー分に抑える）の前提が「新規の不整合を生まない」ことも含む以上、見送るのが妥当と判断 | 2026-09-10 |
| 7 | Requirement 11.1の判定は「保有集合ちょうど1件が対応先と一致するか」ではなく「保有集合に対応先カテゴリーが1つでも含まれるか」（存在判定）で行う。重複保有・同系統内複数保有等の既存不整合が対応先と同席していても、対応先が含まれる限り新規付与判定を継続する（既存不整合行そのものへの変更は一切行わない） | Requirement 7.1（既存不整合への不介入）は「既存の不整合データそのものを変更しない」ことを意味し、「不整合データが存在する選手への無関係な新規処理まで一律に見送る」ことまでは求めていない、という人間の解釈による。見送り一辺倒は「なぜ発火しないか分からない」という運用上の不透明さを生む一方、新規付与は既存カテゴリーをcancelしない・エントリー成立やリザルト記録を妨げない・catracer-cleanup-2026-27で事後是正可能という理由で実害が小さい。**この方針はentry-auto-category-2026-27固有ではなく、Cyclox全体の既定方針として`.kiro/steering/existing-data-inconsistency-policy.md`に明文化し、今後の全specに適用する**（適用条件: 新規処理が既存データを変更しない／誤って実行されても実害が小さく事後是正可能、の両方を満たす場合に限る） | 2026-09-10 |
| 8 | Requirement 11.4を改訂し、エントリー側の保有確認基準を相手系統確認（Requirement 1）から分離する。エントリー側は`apply_date <= $atDate`（$atDate時点で実際に発効していたカテゴリーのみ）を基準とし、相手系統側は引き続き`apply_date`の下限を設けない | タスク2.1 round 3レビューで、決定事項#7の存在判定（保有集合に対応先が含まれるか）と、apply_dateの下限を設けない集合取得が組み合わさることで、まだ発効していない（将来のapply_dateを持つ）切替予定カテゴリーまで「現在の保有」とみなされ、正常なカテゴリー切替の途中（既存不整合ではない）で本機能自身が新たな対応外ペアを生成することを独立レビュアーが実際にコードを実行して実証（マスターズ側でCM3→CM2へ正常に切替予定の選手が切替前の大会日でCM3種目へエントリーすると{C4, CM2}という対応外ペアが生成される）。相手系統確認（重複付与の予防が目的でapply_dateの下限を設けないのが正しい）とエントリー側確認（$atDate時点の実際の状態確認が目的）は目的が異なるため、Requirement 11.4が両者に同一基準を強制していたこと自体が誤りだったと判断し、基準を分離する | 2026-09-10 |
| 9 | 決定事項#8の`apply_date <= $atDate`絞り込みを実装後、round 4レビューで「決定事項#8が解消したはずのシナリオ（マスターズ側でCM3→CM2へ切替予定の選手が切替前にCM3種目へエントリーする）が実際には解消されていない」ことが再度実証された（付与されるC4が無期限=cancel_date null のため、CM2への切替発効後に{C4, CM2}の対応外ペアが成立する。システム自身の`CategoryRacer::afterSave()`整合性検知が`mismatched_pair`警告を実際に記録することも確認済み）。この残存シナリオについて、実運用での発生可能性をコード調査・実データ調査で検証した結果、**残存リスクとして受容する**と判断した | 調査結果: (1) コード上、C1〜C4・CM1〜CM3（実力別カテゴリー）に対して「片方の系統だけを未来日で自動生成する」ロジックは存在しない（`AgedCategoryComponent`は`is_aged_category=1`のみを対象に厳密に絞り込んでおり、実力別カテゴリーには一切触れない。`grep`で確認）。(2) 実データを`apply_date > CURDATE()`で調査した結果、該当パターンは選手`KNS-234-0078`の4行（id 90402〜90405、category_code=C4）のみ。これは人間が投入したテストデータの残骸と判断した（reason_note「年少者カテゴリー自動付与」は自由記述であり、対応する自動化ロジックが実在しないため、実際の運用で生成されたものではない）。(3) 選手が近接する日程の複数レースへ同時にエントリーし、先のレースで昇格するケースについては、1レース目のエントリー時点で相手系統が既に付与されるため、2レース目のエントリー処理では相手系統が「既保有」としてスキップされ、問題が発生しないことをコード追跡で確認した。以上より、本シナリオを引き起こす実運用パターン（シーズン切替時の片方系統だけの未来日先行登録）は実質的に発生しないと判断し、これ以上の実装変更は行わない。`.kiro/steering/existing-data-inconsistency-policy.md`に「有効期間を持つデータへの存在判定の注意点」として本件の教訓を追記した | 2026-09-13 |
| 10 | `SKIPPED_NOT_SINGLE_CATEGORY`（プール種目・対応表対象外種目）は、他の見送り理由（`SKIPPED_ENTRY_SIDE_MISMATCH`・`SKIPPED_ALREADY_OCCUPIED`・`SKIPPED_AGE_INELIGIBLE`）と異なり、画面Flash・API応答への警告として出さない（サーバログには引き続き記録する） | タスク3.1（`EntryRacer::afterSave()`統合）の実装検討で、design.mdの「いずれも見送りとしてRequirement 6の通知経路で伝達する」という記述を文字通り実装すると、全エントリーの1.8%を占めるプール種目エントリーの**すべて**に見送り警告が表示されることになると判明。プール種目は本機能の対象外というだけであり（Requirement 4.2: 既存の手動運用に影響を与えない）、他の3つの見送り理由（「判定は行ったが条件を満たさなかった」）とは性質が異なる。運営者にとって実質的なノイズになる懸念から、警告対象外とする | 2026-09-13 |
| 11 | 出走ステータスが「オープン」（`RacerEntryStatus::$OPEN`）のエントリーは対応ペア補完判定の対象外とする（Requirement 5.4として新設） | タスク3.1実装レビューで、新規テストが全て`entry_status=1`（オープン参加）で書かれており実装も`entry_status`を一切参照していないことが判明。既存コード（`ResultParamCalcComponent`）が昇格・ポイント集計から一貫してオープン参加を除外している慣習に倣い、本機能もオープン参加を対象外とする | 2026-09-13 |
| 12 | 資格年齢未達（`SKIPPED_AGE_INELIGIBLE`）による見送りは、`SKIPPED_NOT_SINGLE_CATEGORY`（プール種目）と同様に画面Flash・API応答への警告表示の対象外とする（サーバログへの記録は継続、Requirement 3.2改訂） | タスク3.1 round 2レビューで、実データ測定（season_id=16、entry_status=0の単一対応種目エントリー14,916件）によりエリート系種目エントリーの約28%（4,181件）で資格年齢未達の見送りが発生することが判明。決定事項#10でノイズと判断したプール種目除外（1.8%）の15倍の規模。人間の判断: 資格年齢未達の見送りは「本機能が資格のない選手への誤付与を正しく防いだ結果」であり、運営者の対応を要する異常事態ではないため、画面/API配信は不要（誤付与しないことが正常動作）。要件変更に伴う承認ゲートの往復は人間の指示により省略し、ドキュメント記録のみで直接実装する | 2026-09-13 |
| 13 | 相手系統に既に有効カテゴリーを保有している場合の見送り（`SKIPPED_ALREADY_OCCUPIED`）を、対応表上の正しい連動先を既に保有している場合（`NO_SUPPLEMENT_ALREADY_VALID`として新設）と、対応外ペアを保有している場合（従来どおり`SKIPPED_ALREADY_OCCUPIED`）とに分離し、前者のみ画面Flash・API応答への警告表示の対象外とする（サーバログへの記録は継続） | タスク4.1/4.2実装後のround 4レビューで、`SKIPPED_ALREADY_OCCUPIED`が両者を区別せず一律に警告することが指摘された。開発DB実測（season_id=16、entry_status=0の単一対応種目エントリー14,916件・実人数2,625名、1人あたり平均5.7件）では、現時点で相手系統を既に保有しているエントリーは103件（0.7%）だが、これは本機能が本specの目的どおり機能して対応ペアが一度成立した後は、当該選手の2回目以降のエントリーの大半で恒常的にこの警告が発生する構造であることを意味する（決定事項#10のプール種目1.8%・決定事項#12の資格年齢未達28%と同種のノイズ理由だが、当初は考慮されていなかった）。人間の判断: 対応表上の正しいペアが既に成立している状態は運営者の対応を要しない「既に正常な状態」であり、対応外ペア（要対応）とは区別して画面/API配信対象から除外する。あわせて、本機能の主要な実運用入力経路は外部連携クライアント（cyclox2app等）からのエントリーデータアップロードAPI（`ApiController::execAddEntry()`）であり、管理画面（`EntryRacersController`の個別登録・編集）は主催者による手動登録・修正時に限定的に使われる想定であることを人間に確認した（運用知識に基づく前提、詳細な使用比率は本specの検証範囲外） | 2026-09-13 |
| 14 | round 4レビューが指摘したブロッキング（`ApiController::execAddEntry()`の成功応答`array('ok')`へ文字列キーを混在させるとJSON配列からJSONオブジェクトへ型が変わる問題）を、警告集計を数値添字の追加要素として載せる方式（`$result[] = array('category_supplement_warnings' => ...)`）で修正した。ただしround 5レビューで、この修正はJSON**配列**であることは維持するが、要素の型が`["ok"]`（文字列のみ）から`["ok", {オブジェクト}]`（異種混在）に変わる点は解消していないと指摘された（`List<String>`相当で厳格にデコードする外部クライアントには依然としてリスクが残る）。本リポジトリに実際のクライアント実装（cyclox2app）が無いため確定的な判定はできない。決定事項#9（残存リスクの受容）と同種の性質（実運用での発生可能性・実害が小さいと判断できる範囲の残存リスク）と判断し、オーケストレーターの判断で**残存リスクとして受容し次工程へ進める**: 見送りが無い場合（実運用の大半を占める想定、決定事項#13適用後はさらに減少見込み）は応答が既存形式と完全に一致することをテストで保証済みであり、見送りが発生する場合のみ生じる残存リスクは実害が発生した場合に追跡・対応可能と判断した。人間による事後確認を推奨する | Claude Code（round 5レビュー指摘を受けて記録） |
| 15 | 元ME1特例（過去のC1保有歴でCM1の連動先をC1へ引き上げる）を撤廃する。CM1種目へのエントリーによる補完付与先は常にC2。ME1保有者（大会開催日時点でC1を有効保有）がマスターズ系統種目へエントリーした場合は補完を発動させず、通知上は決定事項#13の「既に正常な状態」と同じ扱い（ログのみ）とする。誤付与3件（category_racers id 268502 / 268546 / 268556）のデータ是正は別途実施 | 本番（2026-09-20〜22）で過去にC1を保有していただけの3名へC1が誤付与された。AJOCC規則「MM1からME1への移行は、元がME1の場合に限る」は移行を認める範囲の上限であって自動付与の根拠ではなく、「元がME1」は現にC1を保有している状態を指す（me-mm-linkage-2026-27 第3版で再定義）。第5版Requirement 2.2が特例をエントリー補完の文脈で再検討せずに流用し、catracer-cleanup-2026-27 research.mdの「元ME1でもC1は自動付与しない」決定とspec横断で食い違っていたことを検出できなかった | 2026-09-25 |

---

## 却下・保留事項

| 内容 | 理由 |
|---|---|
| 選択肢A（単独保有者への一括バッチ付与） | 年齢資格チェックが既存コードにも無くMM資格のない選手にマスターズが付与されるリスク、ME1一括付与によるseason-rules-2026-27連動降格の副作用（年間90名規模が対応外ペアへ落ちる）、既存不整合406名との干渉、休眠選手約8,800名も一律で処理対象になる運用負荷、が理由。本specのスコープには含めない |
| 直近出走実績者への小規模backfill（選択肢Aの限定版） | 判断ブリーフで検討の余地を残したが、本spec初期化時点では選択肢Bのみをスコープとし、backfillは別途・任意の検討課題として棚上げ | 2026-09-07 |
| 既に発生している資格年齢要件違反データ（3件確認済み）の遡及是正 | 既存カテゴリーを一存でcancelしない、という全spec共通の設計哲学に反する。是正するなら年齢違反専用の一時対応が別途必要（catracer-cleanup-2026-27とはスコープが異なる）。本specのスコープには含めない | 2026-09-09 |

---

## フェーズゲート承認記録

> 承認状態の正本は `.kiro/specs/entry-auto-category-2026-27/spec.json` の
> `approvals.{requirements,design,tasks}.approved`。
> ここではブール値を二重管理せず、合意の経緯・補足のみを残す。

| フェーズ | 合意メモ（理由・補足） |
|---|---|
| 要件定義（requirements.md） | 第1版（Requirements 1〜7）は2026-09-07人間承認済み。**第2版（Requirement 8〜10を追加）も2026-09-09人間承認済み**（PRレビュー確認のうえ「進んで良い」、PR自体は未マージのままブランチ上で承認）。propagateLinkedPromotion()・catracer-cleanup-2026-27是正バッチへの資格年齢ガード追加を対象に含め、新規選手CSV登録・change_emは明示的に対象外とした。EARSレビューゲート（実装言語混入なし・番号付き見出し）通過済み |
| 設計（design.md） | **2026-09-09、PRレビュー確認のうえ「進んで良い」と口頭承認（PR未マージ）。** 第2版へ改訂済み。`propagateLinkedPromotion()`・`CatRacerCleanupShell::__applyFixDecision()`への資格年齢チェック挿入、共通判定関数`isAgeEligibleForCategory()`の新設を反映。レビューゲート（要件トレーサビリティ34件・境界4区分・File Structure Plan整合性）通過済み |
| タスク分解・実装前確認（tasks.md） | **2026-09-09 人間承認済み。** 7大タスク・11サブタスクに分解。基盤整備（資格年齢判定・種目解決）→エントリー時補完のCore実装→保存フック統合→警告配信のIntegration→昇格連動・是正バッチへのガード適用→ログ記録統合→統合/E2E検証、の順。要件34件全件・自然言語記述・境界整合性のレビューゲート通過済み |
| 要件定義（requirements.md、第3版） | **2026-09-10 人間承認済み。** Requirement 11（エントリー側保有カテゴリーとの整合性確認）を新設 |
| 設計（design.md、第3版） | **2026-09-10 人間承認済み。** `supplementPairedCategoryOnEntryRegistration()`にエントリー側整合性チェック（`SKIPPED_ENTRY_SIDE_MISMATCH`）を追加。`apply_date`範囲判定バグの修正（新設`__findCurrentlyActiveCategoryRacerOnSide()`）も反映 |
| 要件定義（requirements.md、第4版） | **2026-09-10 人間承認済み。** Requirement 11.1/11.2を完全一致判定から存在判定へ改訂（決定事項#7） |
| 設計（design.md、第4版） | **2026-09-10 人間承認済み。** エントリー側保有確認を`find('all')`ベースの集合の存在判定へ変更（新設`__findCurrentlyActiveCategoryCodesOnSide()`）。round 2レビューで実証された物理行順依存の非決定性を解消 |
| 要件定義（requirements.md、第5版） | **2026-09-10 人間承認済み。** Requirement 11.4を改訂し、エントリー側の保有確認基準を相手系統確認（Requirement 1）から分離（決定事項#8） |
| 設計（design.md、第5版） | **2026-09-10 人間承認済み。** エントリー側保有確認専用の`apply_date`絞り込み付きヘルパー`__findCategoryCodesEffectiveAsOfDateOnSide()`を新設。round 3レビューで実証された対応外ペア生成バグを解消 |
| 要件定義（requirements.md、第6版） | **2026-09-25 人間承認済み。** Requirement 2.2を改訂（CM1種目の補完付与先を常にC2）、Requirement 1.5を新設（ME1保有者のマスターズ系統種目エントリーでは補完を発動しない）。決定事項#15。me-mm-linkage-2026-27 第3版と同時に承認を得る |
| 設計（design.md、第6版） | **2026-09-25 人間承認済み。** 付与先を`pairedCategory()`で直接求め、マスターズ系統種目でC1保有者は`noSupplementAlreadyValid('C1')`。me-mm-linkage-2026-27 design第3版と同時承認。タスクはE1（未承認） |

---

## 変更履歴

| 日付 | 変更内容 | 変更者 |
|---|---|---|
| 2026-09-07 | 初版作成（spec初期化。判断ブリーフの内容を反映） | Claude Code |
| 2026-09-08 | 要件定義フェーズ実施。プール種目を対象外とする決定（#3）を追加し、requirements.mdにRequirement 1〜7を生成 | Claude Code |
| 2026-09-08 | 要件定義（Requirements 1〜7）を人間承認。spec.json phase=requirements-approved | kyamady |
| 2026-09-08 | 設計フェーズ実施（light discovery）。research.md・design.mdを生成。spec.json phase=design-generated | Claude Code |
| 2026-09-09 | `EntryRacer::afterSave()`まわりの解説アーティファクト作成の過程で、資格年齢ガードの欠落を横断的に発見（実データで3件の違反を確認）。決定事項#4・#5に基づき要件を改訂し、Requirement 8〜10を新設。spec.json phase=requirements-generated（第2版・未承認）に巻き戻し | Claude Code |
| 2026-09-09 | 要件第2版（Requirement 8〜10）を人間承認（PR #69確認のうえ、未マージのまま「進んで良い」） | kyamady |
| 2026-09-09 | design.mdを第2版へ改訂。propagateLinkedPromotion()・CatRacerCleanupShellへの資格年齢チェック挿入、isAgeEligibleForCategory()新設を反映。同一PR（#69）に積む形で対応。spec.json phase=design-generated | Claude Code |
| 2026-09-09 | tasks.mdを生成（7大タスク・11サブタスク）。requirements.approved・design.approvedをtrueに設定。spec.json phase=tasks-generated | Claude Code |
| 2026-09-09 | 実装前の環境確認を実施。cyclox2_mysqlのOOM Killを検知・復旧、本specが触る6ファイル計140テストのベースラインgreenを確認。副次的にcyclox2_svrのhttpdワーカーメモリ肥大化を発見し、別spec httpd-worker-memory-leak-2026-09としてハンズオフbriefを切り出した（PR #70） | Claude Code |
| 2026-09-09 | タスク分解（tasks.md）を人間承認。spec.json tasks.approved=true、ready_for_implementation=true | kyamady |
| 2026-09-10 | タスク1.1・1.2をTDDで実装・独立レビュー3ラウンド（REJECTED×2→APPROVED）を経てマージ（submodule PR #25、main repo PR #72・#73） | Claude Code |
| 2026-09-10 | タスク2.1をTDDで実装したが独立レビューでREJECTED。実装バグ1件（apply_date範囲判定の転用ミス）に加え、要件レベルの前提崩れ（エントリー先種目と選手の実際の保有が食い違う場合に本機能が新たな対応外ペアを作る）をレビュアーが実証。人間に共有し対応方針（決定事項#6）を確認。requirements.mdにRequirement 11を新設し第3版へ改訂、spec.json requirements.approved/design.approvedをfalseに巻き戻し | Claude Code |
| 2026-09-10 | 要件第3版（Requirement 11）を人間承認。design.mdを第3版へ改訂（SKIPPED_ENTRY_SIDE_MISMATCH新設、apply_dateバグ修正方針を反映）し人間承認。spec.json requirements.approved/design.approved/ready_for_implementationをtrueに復帰 | kyamady |
| 2026-09-10 | タスク2.1を再実装したが独立レビュー round 2でREJECTED。エントリー側整合性チェックが`find('first')`で1行しか見ないため物理行順に依存して非決定的になること、同一カテゴリーの重複保有が素通りすることをレビュアーが実際にコードを実行して実証。人間に共有 | Claude Code |
| 2026-09-10 | 人間より、Requirement 7.1（既存不整合への不介入）の解釈を「不整合行そのものを変更しない」に限定し、「不整合の存在を理由に無関係な新規処理まで一律に見送らない」という方針を採用する指示（決定事項#7）。Cyclox全体の既定方針として`.kiro/steering/existing-data-inconsistency-policy.md`を新規作成。requirements.md・design.mdを第4版へ改訂（Requirement 11.1/11.2を完全一致判定から存在判定へ、`find('all')`ベースの新設`__findCurrentlyActiveCategoryCodesOnSide()`を反映）し人間承認。spec.json requirements.approved/design.approved/ready_for_implementationをtrueに復帰 | kyamady |
| 2026-09-10 | タスク2.1を第4版方針で再実装したが独立レビュー round 3でREJECTED。存在判定とapply_date下限なしの集合取得が組み合わさることで、まだ発効していない切替予定カテゴリーまで「現在の保有」とみなされ、正常なカテゴリー切替の途中で本機能自身が新たな対応外ペアを生成することをレビュアーが実証。加えて、オーケストレーター自身のミューテーションテスト報告に不正確な点（`testSupplementProceedsWhenEntrySideHasDuplicateOfMatchingCategory`が実際にはどの変異も検知していなかった）があったこともレビュアーが指摘。人間に共有し対応方針（決定事項#8）を確認 | Claude Code |
| 2026-09-10 | Requirement 11.4を改訂し、エントリー側の保有確認基準を相手系統確認から分離（決定事項#8）。requirements.md・design.mdを第5版へ改訂（`apply_date <= $atDate`を絞り込む新設`__findCategoryCodesEffectiveAsOfDateOnSide()`を反映）し人間承認。spec.json requirements.approved/design.approved/ready_for_implementationをtrueに復帰 | kyamady |
| 2026-09-10 | タスク2.1を第5版方針で再実装したが独立レビュー round 4でREJECTED。決定事項#8で「解消した」としていたシナリオ（CM3→CM2切替予定選手の切替前エントリー）が実際には解消されていないことをレビュアーが実際にコードを実行して再実証（付与C4が無期限のため切替発効後に対応外ペアが成立、本番コードのmismatched_pair警告も確認）。加えて、オーケストレーターが「バグ再現テスト」として書いたテストが、被テストコードと同じロジックで比較用データを自前計算するトートロジーであり実際には何も検証していないことも指摘 | Claude Code |
| 2026-09-13 | 人間より、このシナリオの実運用発生可能性について懐疑的な指摘（「エントリー時のカテゴリー食い違いは、前段のCycloxApp人間目視を通過したエントリーでは考えにくい」「近接レース同時エントリーのケースは1レース目の付与で相手系統が既に埋まるため無害」）。指示に基づきコード調査（`AgedCategoryComponent`が`is_aged_category=1`限定であることを確認）・実データ調査（`apply_date > CURDATE()`の該当行を全DB検索）を実施し、報告した結果、いずれも実運用パターンではなくテストデータの残骸と判明。決定事項#9として残存リスクを受容する方針を確定。以降、レビュー往復では指摘のリスク度合いを自ら判断し、判断できない場合のみ人間に確認する運用へ切替（フィードバック） | kyamady |
| 2026-09-13 | タスク3.1（`EntryRacer::afterSave()`統合）着手にあたり、`SKIPPED_NOT_SINGLE_CATEGORY`を警告配信対象から除外する決定（決定事項#10）を人間に確認・承認。design.mdのError Categories and Responsesに明確化の注記を追記 | kyamady |
| 2026-09-13 | タスク3.1を実装したが独立レビューでREJECTED。ブロッキング3件を実際にコードを実行して実証: (1) `EntryRacer`のソフト削除が`save()`を経由するため、削除操作でも`afterSave()`が発火し、条件次第で削除の副作用として新規カテゴリー付与が発生しうる、(2) 例外捕捉（Requirement 6.1/6.2）がテストで一切検証されていない、(3) `Meet.at_date`の配線がミューテーションで生存し実質無検証。加えて中程度の指摘（FAILURE時の検証エラー情報の欠落、警告の重複排除欠如、ログスコープ未登録）と、仕様上の空白（オープン参加の扱い未定義、新規テストが全てentry_status=1で書かれていた）を発見。オープン参加の扱いについて人間に確認し、対象外とする決定（決定事項#11）を得た。Requirement 5.3を強化（ソフト削除経由のsave()も新規付与のトリガーにしてはならない旨を明記）、Requirement 5.4を新設。design.mdに反映のうえ実装を修正する | Claude Code |
| 2026-09-13 | タスク3.1を修正し独立レビューround 2を実施したがREJECTED。ブロッキング2件を実際にコードを実行して実証: (1) テストダブル`ThrowingEntryRacerForTest`が`new`時にtestデータソースを明示指定していなかったため、CakePHPのtest datasource切替（`ClassRegistry::init()`経由でのみ有効）が効かず、開発DB（`cyclox2.entry_racers`）へ23行の実データが漏洩していたことをレビュアーが実測で発見。人間の許可を得て該当行を削除、(2) `SKIPPED_ALREADY_OCCUPIED`の警告文言が`getCategoryCode()`の値（見送り対象だった連動先）を「既に保有している」かのように誤読させる表現だったことをレビュアーが実測（18%の実ケースで誤読が生じうる）で実証。中程度・軽微の指摘4件（design.mdの誤記訂正、bootstrap.phpのログスコープ説明の訂正、JSON_UNESCAPED_UNICODE欠落等）は自己判断で修正 | Claude Code |
| 2026-09-13 | 資格年齢未達（`SKIPPED_AGE_INELIGIBLE`）が実データでエリート系種目エントリーの約28%を占めることがround 2レビューで判明し、画面/API配信の要否について人間に確認。決定事項#12として除外を承認。要件変更に伴う承認ゲートの往復は人間の指示により省略し、ドキュメント記録のみで反映（requirements.md Requirement 3.2/6.4/6.5、design.md Error Categories and Responses）。実装（`EntryRacer::__recordCategorySupplementOutcome()`への早期return追加）・テスト更新・ミューテーションテストを実施し、独立レビューround 3を実施してAPPROVED。タスク3.1完了（submodule commit `0dc1667`、feat/entry-auto-category-2026-27-entry-hookブランチへpush） | Claude Code |
| 2026-09-13 | タスク4.1（`EntryRacersController`での警告配信）・4.2（`ApiController`一括経路）・5.1（`propagateLinkedPromotion()`への資格年齢ガード、`CategoryLineagePropagationResult::SKIPPED_AGE_INELIGIBLE`新設）・5.2（`CatRacerCleanupShell`への資格年齢ガード、`_isGrantCategoryAgeEligible()`テスタビリティ用シーム新設）・6.1（`ResultParamCalcComponent`の2箇所の昇格連動呼び出しへのログ記録統合）・7.1/7.2（`Integration/EntryAutoCategoryIntegrationTest.php`新設、全経路の同一基準確認・E2Eシナリオ確認）をTDD＋ミューテーションテストで実装。タスク5.2実装中、既存テスト2件（保存失敗時ロールバック検証・エラーレポートログ検証）が、fixture選手R0037が実際に資格年齢未達（CX年齢32歳、連動先CM1は35歳要件）であったため新設ガードに意図せず横取りされて破綻することを発見。当該2テストの意図（資格年齢とは無関係の保存失敗検証）を保つため、逆方向のテスト注入フック`forceAgeEligibleForRacerCode`を新設して救済 | Claude Code |
| 2026-09-13 | タスク4.1〜7.2の独立レビュー（round 4）を実施したがREJECTED。ブロッキング1件を実測で実証: `ApiController::execAddEntry()`の成功応答（`array('ok')`という数値添字リスト）へ`category_supplement_warnings`を文字列キーとして追加すると、見送りが1件でも発生した瞬間に応答のJSON型が配列からオブジェクトへ変わり（`["ok"]`→`{"0":"ok","category_supplement_warnings":[...]}`）、厳格な型でデコードする外部連携クライアントの成功/失敗判定を壊しうる（Requirement 6.6違反）。中程度の指摘5件（一括API警告に件数上限が無い、是正バッチのレポート内容がテストで未保護、個別API経路の結合テストが前段の警告混入で汚染されうる、昇格連動ログが専用スコープ未使用、等）と軽microな指摘7件も自己判断で修正した。警告応答は数値添字の追加要素（JSON配列を維持）へ変更し、`MAX_LINEAGE_WARNINGS_IN_RESPONSE`による上限を追加。`EntryRacersController`の3経路に防御的な`resetCategorySupplementWarnings()`を追加。`CatRacerCleanupShell`のレポート内容にstdoutアサーションを追加。是正バッチの資格年齢基準日欠落時のフォールバックを安全側に修正。`ResultParamCalcComponent`の新規ログを`entry_auto_category`スコープへ変更。統合テストの前提誤り2件を修正しN-5の恒真に近いテストを強化 | Claude Code |
| 2026-09-13 | round 4レビューの中程度指摘の1つ（`SKIPPED_ALREADY_OCCUPIED`が対応表上の正しいペアを既に保有している場合も対応外ペアの場合も区別せず警告する構造。実データ実測で対応ペア成立後の再エントリーの大半に恒常的な警告が発生しうることが判明）について、決定事項#10・#12と同種のノイズ判断のため人間に確認。決定事項#13として、正しいペアを既に保有している場合のみ警告対象から除外する方針（`CategoryLineageSupplementResult::NO_SUPPLEMENT_ALREADY_VALID`を新設）を承認。あわせて、本機能の主要な実運用入力経路が外部連携クライアント（cyclox2app等）からのエントリーデータアップロードAPIであるとの人間の運用知識を確認。requirements.md（Requirement 1.3・6.4・6.5）・design.md（Error Categories and Responses、State Management、シーケンス図）へ反映し、実装（`CategoryLineageLinker::supplementPairedCategoryOnEntryRegistration()`の判定分岐、`EntryRacer::__recordCategorySupplementOutcome()`の早期return）・既存テスト3件の更新・新規テスト追加・ミューテーションテストを実施 | Claude Code |
| 2026-09-13 | round 4の全修正（決定事項#13含む）に対する独立レビュー（round 5）を実施し、APPROVED。ブロッキングなし。中程度2件を検出: (A) 見送りゼロ時の応答不変性を検証するテストが`assertArrayNotHasKey`によるトップレベルキーのみの検査であり、警告が常時追加される回帰を検知できないことをミューテーションテストで実証（`assertSame(array('ok'), $ret)`へ強化して修正）。(B) 相手系統が同系統内複数保有（既存不整合の一種）を持つ場合、決定事項#13の等値比較（`find('first')`の1行取得）が物理行順に依存し非決定的になりうることを実測で実証（round 2レビューがエントリー側確認で発見・修正した`find('all')`の集合の存在判定への改訂と同型の問題）。エントリー側確認と同じ集合取得方式へ統一する修正（`__findCurrentlyActiveCategoryRacerOnSide()`を`__findCurrentlyActiveCategoryCodesOnSide()`に置き換え）で対応。軽微指摘3件（B-1修正がJSON型は配列のまま維持するが要素型の異種混在は解消していない旨の明記漏れ→決定事項#14として残存リスク受容を記録、docblockの記述不整合2箇所）も自己判断で修正。全14ファイルの回帰を再確認しgreen | Claude Code |
| 2026-09-25 | 本番でCM1エントリーを契機とするC1誤付与3件（CXK-156-0112 / CCS-167-0033 / KNS-000-0601）が判明。原因調査の結果、実装はspecどおりで、第5版Requirement 2.2（元ME1判定による付与先決定）自体が誤りと判明。人間の決定（決定事項#15）に基づきrequirements.mdを第6版へ改訂し、spec.jsonのrequirements/design/tasksのapprovedをfalseに巻き戻し（me-mm-linkage-2026-27 第3版と連動） | Claude Code |
