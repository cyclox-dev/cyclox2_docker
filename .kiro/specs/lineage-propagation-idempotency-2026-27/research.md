# Gap Analysis（実装ギャップ分析）

## Summary

- **Feature**: `lineage-propagation-idempotency-2026-27`
- **Scope**: Bug fix（既存機能の欠陥修正）+ 既存データ是正。新規の機能追加は無い
- **Key Findings**:
  - 根本原因は「**`apply_date <= $atDate`（レース当日時点の所属を問う窓）を、重複防止ガードに
    そのまま流用している**」こと。同種の窓はコード中に**12箇所**あり、うち**用途が「レース
    当日の所属」である11箇所は正しく、「自分が既に書いたか」を問う1箇所だけが誤っている**。
    修正対象はこの1箇所（`__findActiveCategoryRacerOnSide()`）に限られる（1.2、2026-09-24修正）。
  - 混入経緯はc18d056（2026-08-23）の差分で直接確認できる。**改訂前は呼び出し元が「当日+1日」を
    渡しており自己観測性が成立していた**が、+1日の計算をLinker内部へ移す際に**作成行（書き込み）
    にだけ適用し、ガード（読み取り）の窓は据え置いた**。同コミットは検知側
    （`CategoryRacer::$lineageInspectionAtDate`）は正しく追随させており、**同一コミット内で
    読み手が分かれている**。再発防止の記録（Requirement 7）はこの事実を核に書ける。
  - **再取込では`racer_result_id`が毎回変わる**（`ApiController::execAddResult()`が既存
    `RacerResult`を全削除してから作り直す）。したがって冪等キーに`racer_result_id`を含めると
    修正が効かない。既存の昇格元側の削除条件が`racer_result_id`を含んでいないのは正しい設計で
    あり、本修正もこれに倣う必要がある。**回帰テストも同様に、毎回異なるリザルトidを模擬
    しなければ本番障害を再現できない**。
  - 調査中に見つかった2つの別欠陥（「再取込で昇格が取り消される場合に後始末が走らない」＝
    発見1、「同日開催の別大会では同日中に発効した昇格を観測できない」＝1.2の盲点）は、
    いずれも本欠陥とは原因系統・発生時期が異なるため**スコープ外**とした。前者は別セッションへ
    引き渡し済み、後者は実害が観測されていない（1.2参照）。
  - 既存資産の再利用性は高い。テスト基盤・是正SQLの置き場・不整合検出のいずれも先行specの
    パターンをそのまま使える。新規コンポーネントは不要。

---

## 1. Current State Investigation

### 1.1 関係するファイルと責務

| 層 | ファイル | 本件での役割 |
|---|---|---|
| Const | `app/Cyclox/Const/CategoryLineageMap.php` | ME⇔MM対応表の単一定義。**変更不要** |
| Util | `app/Cyclox/Util/CategoryLineageLinker.php` | `propagateLinkedPromotion()`（昇格連動の保存）と`__findActiveCategoryRacerOnSide()`（**主原因**） |
| Component | `app/Controller/Component/ResultParamCalcComponent.php` | 昇格判定と連動の呼び出し元。`__execApplyRankUp()` / `__applyRankUp2CM()` / `__setupCatRacerCancel()` |
| Model | `app/Model/CategoryRacer.php` | `afterSave()`整合性検知。`actsAs = Utils.SoftDelete` |
| Controller | `app/Controller/ApiController.php` | `execAddResult()`。**再取込で既存`RacerResult`を全削除→再作成** |
| Console | `app/Console/Command/CatRacerCleanupShell.php` | 不整合の検出（`detect`）・是正（`cleanup`）・検証（`verify`） |

### 1.2 `apply_date <= $atDate` の全出現箇所と用途の分類

**【2026-09-24 修正】** 初版は「本体7箇所」としていたが、実際は**12箇所**である
（`grep -rn "apply_date <=" app | grep -v "/Test/"` は19行ヒットし、うち7行はコメント行）。
初版の表は7件＋脚注3件の計10件しか挙げておらず、`OrgUtilController` の2件が漏れていた。
また #2 の分類が誤っていた（後述）。用途で切り分けて修正対象を決める設計方針を採る以上、
母集団の正確さが設計の前提になるため、全12箇所を掲載し直す。

| # | 箇所 | 用途 | 窓の妥当性 |
|---|---|---|---|
| 1 | `CategoryLineageLinker::__findActiveCategoryRacerOnSide()` (L454) | **B: 連動先を既に書いたかのガード** | **誤**（主原因・修正対象） |
| 2 | `ResultParamCalcComponent::__applyRankUp2CM()` (L1171) | A: 昇格元側の現在所属の取得（`$hasNewCat`/`$hasCM1`） | 条件付きで正（後述の盲点あり） |
| 3 | `ResultParamCalcComponent::__setupCatRacerCancel()` (L1493) | A: 旧カテゴリーのcancel対象の抽出 | 条件付きで正（後述の盲点あり） |
| 4 | `ResultParamCalcComponent::__getCatCodes()` (L1007) | A: レース当日の所属取得 | 正 |
| 5 | `ResultParamCalcComponent::__checkCatRacer()` (L1686) | A: 指定日の所属確認 | 正 |
| 6 | `ResultParamCalcComponent::__asCategory()` (L1807) | A: 出走カテゴリーの解決 | 正 |
| 7 | `CategoryLineageLinker::isFormerElite1()` (L152) | A: レース当日までのC1履歴 | 正 |
| 8 | `CategoryLineageLinker::__findCategoryCodesEffectiveAsOfDateOnSide()` (L796) | A: エントリー補完のエントリー側確認 | 正 |
| 9 | `CategoryRacer::__activeCategoryCodes()` (L366) | A: 整合性検知の基準日 | 正（呼び出し元から`$atDate + 1日`が渡される） |
| 10 | `CatRacerCleanupShell` (L668) | A: 実行日時点の有効保有 | 正 |
| 11 | `OrgUtilController` (L297) | A: シーズン最終日時点の所属 | 正 |
| 12 | `OrgUtilController` (L394) | A: 大会日時点の所属 | 正 |

**判断軸**: 「レース当日、選手は何を名乗っていたか」を問う判定（A）は `apply_date <= $atDate` が
正しい。「この処理が既に結果を書いていないか」を問う判定（B）に日付窓を使ってはならない。
**目的Bに該当するのは #1 のみ**であり、本specの修正対象はここに限られる。

#### 初版の誤り: #3 `__setupCatRacerCancel()` を「誤」と分類していた件

初版は「前回取込で作った行を拾えない」として誤りに分類していたが、これは**誤読だった**。
本メソッドの第2引数（cancel対象リスト）は全6箇所の呼び出しを確認した結果、**常に昇格“元”の
下位カテゴリー**であり（`__rankUpMap[$racesCat]['needs']`、`array('CL2')`、
`$oldCats = array('CM1' => array('CM2','CM3'), ...)` 等）、**今回作成する連動先・昇格先を
含むことはない**。したがって「前回作った行」は元々このメソッドの対象外であり、窓の有無に
関わらず取りこぼしは発生しない。

同一大会の再取込に限れば、前回cancelした旧行は `cancel_date = $atDate` であり、本メソッドの
条件 `cancel_date >= $atDate` に等号で該当するため再抽出され、同じ値が再設定されるだけで冪等
である（開発DBでも `MMJ-234-3001` の CM2 は `cancel_date = 2026-09-23` の1行のみ）。

#### #2・#3 に共通して残る盲点: 同日開催の別大会

#2・#3 の窓は「レース当日の所属」としては正しいが、**同じ日に別の大会がある場合に、その日の
うちに発効した昇格を観測できない**という副作用を持つ。昇格で作られる行の `apply_date` は
レース当日+1日のため、同日2大会目の判定窓（`apply_date <= 当日`）から外れる。
#2 の冪等化削除は `meet_code` を条件に含むため2大会目には効かず、#3 の cancel も同様に
届かない。結果として同日・同カテゴリーの行が2本できうる。

**この盲点は本欠陥とは別物であり、本specのスコープ外とする**。根拠:

1. **発生時期が違う。** 昇格元側の「新カテゴリーの `apply_date` は当日+1日」という規約は
   c18d056（2026-08-23）より前から存在する（同コミットの差分で当該行は変更されていない
   コンテキスト行）。つまりこの盲点は何年も前から存在する。
2. **実害が観測されていない。** 実データで「同一選手が同一日に2つ以上の異なる大会で出走した」
   選手日は781件ある。しかし昇格・連動由来（`reason_id IN (2, 12)`）の有効行を、由来大会の
   開催日（`meets.at_date`）と突き合わせて重複判定すると、**同一開催日の別大会に由来する重複は
   全期間で0件**である。該当する重複は本欠陥由来の5選手8行のみで、いずれも同一大会
   （`meet_code` が1種類）に由来する。件数ではなくこの形（開催日で突き合わせて0件）で記録する
   のは、`meet_code` だけで判定すると2デーレース（day1/day2 が別 `meet_code`・別 `at_date`）や
   エントリーCSV由来の行が混ざり、誤って「同日別大会の実例あり」と読めてしまうためである
   （実例: `CCM-189-9004` の C3 は Rapha Super Cross Nobeyama の day1/day2 にまたがるが、
   両者は別日であり同日別大会ではない）。同日2大会で連続昇格するには両方で上位に入る必要が
   あり、実際には起きていない。
3. **原因系統が違う。** 本欠陥は「自分が書いた行を自分のガードが見られない」（目的Bの誤用）
   であり、この盲点は「+1日規約と同日開催の相互作用」である。修正方針も共有できない。

#### 決定的証拠: c18d056 の差分

混入経緯は同コミットの差分で直接確認できる。

```
-  propagateLinkedPromotion($racerCode, $newCatCode, $result + ..., $applyDate);
+  propagateLinkedPromotion($racerCode, $newCatCode, $result + ..., $this->__atDate);
```

**改訂前**は呼び出し元が `$applyDate`（＝当日+1日）を渡しており、Linker内ではその値が
ガードの窓にも作成行の `apply_date` にも同じく使われていたため、**自己観測性が成立していた**。
改訂で「+1日の計算をLinker内部へ移す」際、**作成行（書き込み）にだけ+1日を適用し、ガード
（読み取り）の窓は渡された生の `$atDate` のまま据え置いた**ことで、両者が1日ずれた。
同コミットは検知側（`CategoryRacer::$lineageInspectionAtDate` を新設し `$applyDate` を渡す）は
正しく追随させており、**同一コミット内で読み手が分かれている**ことが差分から読み取れる。

### 1.3 再取込の実際の挙動（実データとログで確認済み）

```
ApiController::execAddResult()
  → 「現在ある全てのリザルトデータを削除」（RacerResult->delete = ソフト削除）
  → 新しい racer_results 行を新規idで作成        ← racer_result_id が毎回変わる
  → ResultParamCalcComponent の昇格判定・連動を実行
```

実例（`KNS-000-2879` / `MMJ-267-002`）: 352711 → 352741 → 352889 → 352919 → 353031 の5世代。
昇格元CM1は各回で前回行が削除され常に1行、連動先C2だけが5行に増えた。

### 1.4 既存の冪等化パターン（再利用可能）

`__execApplyRankUp()` / `__applyRankUp2CM()` が持つ削除条件:

```
racer_code + meet_code + category_code + apply_date + reason_id(=RESULT_UP)
```

`racer_result_id`を**含まない**点が重要（1.3の理由により含めてはならない）。連動先側に同型を
適用するなら `reason_id = LINEAGE_LINK` 版になる。

**このパターンが実際に機能していることの物証**: 旧行の `deleted_date` と新行の `created` が
秒まで一致する組（＝同一処理内で削除して作り直した痕跡）が、`reason_id = RESULT_UP` で
**2,148組**存在する。最古の例のひとつは2018年（`CCM-189-9004` の C3、id 25460 の
`deleted_date` と id 25676 の `created` がいずれも `2018-11-28 01:16:30`）。昇格元系統側は
8年前から今日まで同じ方式で有効行を1件に保っており、本specが連動先側へ対称展開する方針
（design.md「Selected pattern」）は、机上の設計ではなく長期に実証されたパターンの踏襲である。

### 1.5 テスト資産

| テスト | 使える点 |
|---|---|
| `ResultParamCalcComponentTest` | `__reCalcResults()` / `__applyRankUp()` をプライベートメソッド呼び出しで直接駆動する仕組みが既にある（`testMainPathViaApplyRankUpPropagatesMastersLinkage`等） |
| `MeMmLinkageIntegrationTest` | `__reCalcResults()`経由の統合シナリオ、既存不整合データとの共存パターンの先例 |
| `CategoryLineageLinkerTest` | `propagateLinkedPromotion()`の単体テスト85件（元ME1特例・年齢未達・HoldPoint重複防止の回帰網） |
| `EntryAutoCategoryIntegrationTest` | 複数経路で同一結果になることを確認する統合テストの書き方 |

**ギャップ**: 「同一リザルトを3回以上取り込む」テストは存在しない。かつ**毎回異なる
`racer_result_id`を与える**必要があるため、既存テストのヘルパーをそのまま反復呼び出しする
だけでは不十分（1.3参照）。

なお「同日開催の別大会を順に取り込む」シナリオのテストは**本specでは追加しない**。本欠陥は
同一リザルトの反復取込で再現し、同日別大会シナリオは1.2の盲点（スコープ外）でのみ露呈する
ため、本specの修正の検証には寄与しない。

### 1.6 データ是正の先例

`.kiro/specs/rider-demotion-2025-26/sql/` および `.kiro/specs/season-rules-2026-27/sql/` に
`01_build_demote_set.sql` / `03_verify.sql` という**「構築SQL＋検証SQL」をspec配下に置き、
人間が実行する**パターンが確立している。Requirement 4.5〜4.7（承認・復元・事後確認）は
この先例にそのまま乗る。

---

## 2. Requirement-to-Asset Map

| Req | 必要な能力 | 既存資産 | ギャップ |
|---|---|---|---|
| 1 再取込の冪等性 | 連動先が既に書かれているかの判定 | `__findActiveCategoryRacerOnSide()`（窓が誤）／昇格元側の削除パターン | **Constraint**: 日付窓を用途で切り分ける必要。**Missing**: 連動先側の冪等化削除 |
| 2 保有判定の正しさ | 未来日の行も観測する判定 | `__findCurrentlyActiveCategoryCodesOnSide()`（エントリー補完用に既存。窓なし） | **Constraint**: 流用すると「終了日<有効開始日」の逆転ケースの分岐が新たに必要 |
| 3 後始末の対象範囲の限定 | 当該取込由来の行のみを特定 | 昇格元側の冪等キー（`racer_code + meet_code + category_code + apply_date + reason_id`） | **Missing**: 連動先側（`reason_id = LINEAGE_LINK`）版の同型実装 |
| 4 既存データ是正 | 対象特定・承認・復元・検証 | spec配下SQL＋`CatRacerCleanupShell detect/verify` | **Missing**: 本欠陥由来に限定した特定クエリ（開発DBで検証済みの雛形あり） |
| 5 既存挙動の維持 | 回帰網 | 単体85件＋統合テスト群 | ギャップ無し（既存テストがそのまま回帰網になる） |
| 6 事後追跡性 | ログ・`reason_note`・`meet_code`/`racer_result_id`列 | 既存の記録項目で充足 | **Missing**: 後始末を行った事実のログ（軽微） |
| 7 再発防止の記録 | steering追記 | `.kiro/steering/existing-data-inconsistency-policy.md` に同型の教訓欄が既にある | ギャップ無し（追記のみ） |

---

## 3. 調査で判明した追加論点

### 発見1: 再取込で「昇格そのものが消える」場合、後始末のコードが存在しない（別課題）

当初「順位訂正で昇格先カテゴリーが変わると前回行が残る」と推定したが、追加調査の結果**この形
では起きない**ことが分かった。昇格先は `$catTo = $this->__rankUpMap[$racesCat]['to']` であり
**種目ごとに固定**で、順位によって変わらない。出走カテゴリーの解決（`__asCategory()`）も
レース当日基準で安定している。

代わりに、実在する穴は次の形である。

- 昇格**人数**は `__rankUpRacerCount($racesCat)`（出走人数依存）、昇格**対象者**は順位順で
  決まる。再取込で順位や出走人数が訂正されると、**前回昇格した選手が今回は昇格しない**
  ことがある。
- この場合、後始末を行うコードは `__execApplyRankUp()` / `__applyRankUp2CM()` の内部にしか
  存在せず、**当該選手についてはそのメソッド自体が呼ばれない**ため、前回の昇格行
  （`reason_id=RESULT_UP`）も連動行（`reason_id=LINEAGE_LINK`）も残る。
  `__doReCalcResults()` にも出走カテゴリー単位の事前クリーンアップは無い（L173〜確認済み）。

**実データによる裏付け**: 「削除済みリザルトを参照したまま有効な昇格行」が11件存在する
（`TKI-234-0073`(2024-01) / `CCM-000-0292`(2023-12) / `CCM-212-9000`(2021-11) 等）。いずれも
再取込で差し替わったリザルトに紐づいており、同一選手の再付与行が存在しない＝再取込後は昇格
対象から外れたのに前回の昇格が残っている状態と判断できる。1件は同大会の生存リザルトが0件
（出走自体が取り消された）。

**重要な性質**:
- 発生頻度は約1件/年（2016〜2024で11件）と低い。
- **本欠陥（2026-08-23の日付規約改訂による回帰）とは独立した、以前から存在する別の穴**。
  旧規約（`apply_date = レース当日`）の時代にも同じ形で発生している。
- **昇格元系統側と連動先系統側の両方**に等しく存在し、解消には出走カテゴリー単位の事前
  クリーンアップという設計変更が要る（影響範囲は昇格処理全体に及ぶ）。

**判断が必要**: Requirement 3.3（再取込で昇格が取り消される場合の後始末）は、本欠陥の修正
とは別系統の変更になる。(i) 本specに含める、(ii) Requirement 3.3を削除し別specへ切る、
(iii) Requirement 3.3を「連動先が昇格元に追随すること」に限定し、昇格元側の穴は別specへ切る。

### 発見2: 修正方式によっては効かない（冪等キーの選択）

`racer_result_id` は再取込のたびに変わるため、冪等キーに含めてはならない（1.3）。
`meet_code + category_code + apply_date + reason_id` を使う既存パターンが正しい。
ただし**同一大会で同一選手が複数種目に出走し、いずれでも同じ連動先へ昇格する**ケースでは、
この条件で前回行を消すことが正しいかを設計で確認する必要がある（結果として連動先が1件に
収束するなら問題ないが、要確認）。

### 発見3: `propagateLinkedPromotion()` は2つの呼び出し元から呼ばれる

`__execApplyRankUp()`（エリート側昇格→マスターズ連動）と `__applyRankUp2CM()`（マスターズ側
昇格→エリート連動）の両方。修正はLinker側に置けば両方に効く（呼び出し元の修正は不要）。

---

## 4. Implementation Approach Options

### Option A: Linker内で冪等化削除を追加する（既存パターンの対称化）

`propagateLinkedPromotion()` の新規作成の直前に、昇格元側と同型の削除
（`racer_code + meet_code + category_code + apply_date + reason_id=LINEAGE_LINK`）を入れる。

- ✅ 既存の確立パターンの対称化であり、レビューでの説明が容易
- ✅ 変更が1メソッド内に閉じる。呼び出し元・テストの構造を変えない
- ✅ Requirement 1・3（連動先側）を同時に満たしやすい
- ❌ 「消してから作る」ため、毎回idが変わる（履歴が追いにくい）
- ❌ ガードの窓（原因A）は残るため、**エントリー補完が先に作った行や他大会由来の行**に対する
  判定漏れは解消しない

### Option B: ガードの日付窓を用途に合わせて修正する

`__findActiveCategoryRacerOnSide()` の `apply_date <= $atDate` を撤廃し、
`__findCurrentlyActiveCategoryCodesOnSide()`（エントリー補完が使っている窓なし版）と同じ
基準に寄せる。あわせて「終了日 < 有効開始日」になる逆転ケースの分岐を追加する。

- ✅ 原因そのもの（自己観測性の欠如）を断つ
- ✅ 他経路が作った行も正しく観測できるようになる
- ❌ 逆転ケースの分岐設計が新たに必要（Requirement 2.3）
- ❌ 「既に保有しているので何もしない」に倒れるため、**昇格先が変わったケース（Requirement
  3）は解決しない**（前回行が残ったまま新規作成もされない、という別の不整合になりうる）

### Option C: A + B（両方）＋ 是正SQL

ガードを正し（B）、かつ再取込に対する後始末を明示的に行う（A）。是正は spec配下SQL＋人間実行。

- ✅ Requirement 1・2・3をすべて満たせる唯一の組み合わせ
- ✅ 原因の除去（B）と、実運用パターンへの直接対処（A）の二重防御
- ❌ 変更点が増え、レビュー負荷が上がる
- ❌ AとBの相互作用（Bで「既保有」と判定される行をAが先に消す、等）の順序設計が必要

---

## 5. Effort & Risk

| 項目 | 評価 | 根拠 |
|---|---|---|
| Effort | **M（3〜7日）** | コード変更自体はS相当だが、(a) 毎回idが変わる再取込を模擬する新しいテスト基盤、(b) AとBの相互作用の設計、(c) 本番データ是正の手順整備、(d) Tier 2の検証往復、で M に積み上がる |
| Risk | **Medium** | 変更対象が稼働中の昇格連動であり、誤ると昇格そのものを壊しうる。一方で既存の回帰網（単体85件＋統合）が厚く、影響範囲が1メソッド＋周辺に限定され、ロールバックも容易 |
| データ是正のRisk | **Low** | 対象8行、ソフト削除のみ、復元可能、判定条件が開発DBで検証済み（過剰削除・取りこぼしともゼロ） |

---

## 6. Recommendations for Design Phase

### 推奨アプローチ

**Option C（A+B）** を推す。Bだけでは Requirement 3 が満たせず、Aだけでは原因が残るため。
ただし設計では次の順序問題を明示的に決めること。

1. まず「この取込に由来する前回の連動先行」を後始末する（A）
2. そのうえで現在の保有状態を判定する（B）
3. 判定結果に応じて新規作成する／しない

### Research Needed（設計フェーズで確定させる項目）

| # | 項目 |
|---|---|
| R1 | 発見1（昇格元側の取りこぼし）の対応範囲。連動先のみ／昇格元も／別spec化 |
| R2 | 後始末の方式。ソフト削除か`cancel_date`設定か（履歴の追跡性と`CategoryRacer::afterSave()`検知への影響で判断） |
| R3 | 「終了日 < 有効開始日」逆転ケースの扱い（Requirement 2.3）。見送り＋記録でよいか |
| R4 | 同一大会・複数種目出走で同じ連動先へ昇格するケースでの冪等キーの妥当性（発見2） |
| R5 | 毎回異なる`racer_result_id`を模擬する反復取込テストの実現方法（`execAddResult()`まで通すか、`__reCalcResults()`＋リザルト作り直しで十分か） |
| R6 | 是正SQLの置き場と実行手順（`.kiro/specs/<id>/sql/` 先例に合わせる） |

### 設計時に流用できる既存資産

- 冪等化削除の書き方: `ResultParamCalcComponent::__execApplyRankUp()` L1318付近
- 窓なしの保有判定: `CategoryLineageLinker::__findCurrentlyActiveCategoryCodesOnSide()`
- 是正SQLの構成: `.kiro/specs/season-rules-2026-27/sql/`（構築＋検証の2本立て）
- 検証手段: `CatRacerCleanupShell detect` / `verify`

---

## 7. 前提・制約の確認

- steering に `product.md` / `tech.md` / `structure.md` は存在しない（`db-category-entry-glossary.md`、
  `existing-data-inconsistency-policy.md`、`handover-ajocc-2026-27.md`、`roadmap.md` のみ）。
  用語は glossary を、既存不整合への向き合い方は inconsistency-policy を参照した。
- `existing-data-inconsistency-policy.md` の「既存の不整合行そのものは変更しない」は、
  **判定ロジックが新規処理を行う際の方針**であり、本specのRequirement 4（自らの欠陥が生んだ
  行の是正）はこれに抵触しない。本specの是正対象は「本欠陥由来と機械的に特定できる行」に
  限定され、それ以外の既存不整合には触れない（Requirement 4.4で明示済み）。
