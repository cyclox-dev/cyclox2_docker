# カテゴリー/種目/エントリー系テーブル用語集

[Purpose: `categories`・`races_categories`・`entry_*` 系テーブル群は名前が似通っており、
初見では「マスタ」と「大会ごとのインスタンス」の区別がつきにくい。混乱の原因と全体構造を
まとめ、以降のセッション・レビューでの再調査コストを減らす]

## 混乱の根本原因

「category」「races_category」という同じ語幹が、**マスタ（恒久定義）**と
**インスタンス（特定大会での実体）**の両方に使われている。`entry_` 接頭辞の有無だけが
両者を区別する唯一の手がかり。

| 語 | マスタ側 | インスタンス側 |
|---|---|---|
| category（資格） | `categories`＝選手が持つ「認定カテゴリー」の定義（C1, CM1, MM40, CL1, WM等） | `category_racers`＝選手個人への資格付与履歴 |
| races_category（種目） | `races_categories`＝大会に依らない「種目」テンプレート定義 | `entry_categories`＝特定の大会で実際に開催された種目インスタンス |
| racer（選手） | `racers`＝選手個人のマスタ | `entry_racers`＝特定エントリーへの選手行（大会当日のスナップショット） |

## テーブルの役割

- **`categories`**: 選手が保持できる「認定カテゴリー」資格そのもの。`code`（PK, 例:
  `C1`,`CM1`,`MM40`,`CL1`,`WM`）・`category_group_id`（`category_groups`参照。1=Elite男子,
  2=Masters男子(年齢別含む), 3=Women女子エリート等）・`is_aged_category`（実力別か年齢別か）を持つ。
- **`category_racers`**: 選手個人への資格付与履歴（`racer_code`+`category_code`+
  `apply_date`/`cancel_date`）。me-mm-linkage-2026-27 の連動更新はここに書き込む。
- **`races_categories`**: 大会エントリー時に選手が選ぶ「種目」のテンプレート。1種目に複数の
  `categories` を束ねられる（例: 種目`C3+4`はカテゴリー`C3`と`C4`の合同種目）。
- **`category_races_categories`**: `races_categories` ↔ `categories` の多対多対応表。
  例: 種目`CL2+3`（JCX表示名「WE2+3」）は`CL2`・`CL3`の2行に紐づく。
- **`entry_groups`**: 特定大会での「スタート集団（ヒート）」。開始時刻・周回設定を持つ。
  `name`は表示ラベルにすぎず、複数種目が混走することがある。
- **`entry_categories`**: 特定大会・特定ヒート内で実際に開催される「種目レース」1件。
  `races_category_code`に加え、大会ごとに変わりうる運用設定（`applies_hold_pt` 保持ポイント対象か
  ／`applies_rank_up` 昇格判定対象か／`applies_ajocc_pt` AJOCCポイント対象か／`holding_status`
  開催状態）を持つ。順位・昇格・ポイント集計はこの単位で行う。
- **`entry_racers`**: 特定`entry_categories`にエントリーした選手1名の行。`name_at_race`等、
  大会当日のスナップショットを保持する（選手マスタの改名等に影響されない）。

## 具体例（実データで確認済み）

ある大会のヒート（`entry_groups.id=2`, 開始11:50, name="C2+CM1+2+3+CL1"）は、
同時スタートでも3つの`entry_categories`に分かれる:

```
entry_groups(id=2, start=11:50) ─┬─ entry_categories(id=2, races_category_code='C2')
                                  ├─ entry_categories(id=3, races_category_code='CM1+2+3')
                                  └─ entry_categories(id=4, races_category_code='CL1')
```

同じコースを同時に走っていても、順位判定・昇格判定・ポイント計算は`entry_categories`単位
（＝カテゴリー単位）で完全に独立して行われる。`entry_groups`だけでは種目を区別できない。

## 全体の依存関係

```
categories ──category_group_id──> category_groups
    │
    └──(category_races_categories, 多対多)──> races_categories
                                                       │
entry_groups(meet_code) ──1:N──> entry_categories(races_category_code) ──1:N──> entry_racers
```

## 成績対象カテゴリー（`racer_results.as_category`）と対応表の落とし穴

**【2026-11-24追記】** `uciwj-wj-ranking-fix-2026-11` で、UCI-Women Junior（種目 `UCIWJ`）の AJOCC
ポイントが WJ ランキングに載らない不具合を是正した際に確定した原因と再発防止策。

### 機械的原因
- `as_category` はリザルト取込時（管理画面アップロード・アプリ API の両経路）に
  `ResultParamCalcComponent::__asCategory()` で**1回だけ**決まる。種目に紐づくカテゴリーが
  `category_races_categories` に1件ならそれ（選手の保有に関係なく）、**0件なら種目コードそのもの**が入る。
- AJOCC ランキング生成（`ResultShell::updateAjoccPtRankings`）は、`categories` に存在しない
  as_category を「カテゴリーとして認識されません」（LOG_INFO のみ）でスキップし、フラグは処理済みにする。
  集計側も `as_category == カテゴリーコード` の成績しか数えない。
  → **対応表に行が無い種目の成績は、ポイントが付与されていても、どのランキングにも載らず、誰にも通知されない。**
- 管理画面の「リザルトを再計算する」は as_category を書き換えないので、運用側では直せない。

### プロセス上の欠陥
- 種目マスタ（`races_categories`）の追加・初使用時に、対応表の登録を確認する手順が無かった。
  UCI 種目は普段 AJOCC ポイント付与なしの全日本選手権で使われるため、付与ありの大会で初めて
  使われたときに漏れが表面化する（2016-17 UCIMJ、2023-24 / 2026-27 UCIWJ で同じ形の漏れ）。
- 漏れはログに INFO で出るだけで、管理画面の表示（`1000pt/UCIWJ` のように as_category が併記される）を
  見比べないと気づけない。

### 再発防止策（確認手順）
- **AJOCC ポイント付与ありで、対応表が未登録の種目（特に UCI 系）を使う前に、対応を登録する。**
  登録したら、デスクトップアプリへ配信するため、その種目の `races_categories.modified` も更新する
  （アプリの基本データ同期は「いずれかの種目の modified が前回同期より新しい」ときだけ対応一覧を再送する）。
- シーズン中の点検用 SQL（0件が正常。`season_id` は対象シーズンに置き換える）:
  ```sql
  SELECT m.code, ec.id AS ecat, ec.races_category_code, rr.as_category, COUNT(*) AS n
    FROM racer_results rr
    JOIN entry_racers er ON er.id = rr.entry_racer_id
    JOIN entry_categories ec ON ec.id = er.entry_category_id
    JOIN entry_groups eg ON eg.id = ec.entry_group_id
    JOIN meets m ON m.code = eg.meet_code
    LEFT JOIN categories c ON c.code = rr.as_category AND c.deleted = 0
   WHERE rr.deleted = 0 AND er.deleted = 0 AND ec.deleted = 0 AND m.deleted = 0
     AND ec.applies_ajocc_pt = 1 AND m.season_id = 17 AND c.code IS NULL
   GROUP BY 1, 2, 3, 4;
  ```
  なお `CC` / `Exhibition` 等のオープン種目もここに出る（2026-27 時点で E5・W19-34・M19-34 等）。
  UCI 系・カテゴリー別種目が出たら要対応。
- 既存成績の是正は、対応を登録したうえで `as_category` を列単位で更新し、`tmp_result_update_flags` に
  フラグを立てて既存の毎時バッチに再生成させる（手順・SQL は当該 spec の `runbook.md` / `sql/`）。

### 対応表の変更が波及する先（影響調査で見落としやすい）
- **公開サイト（ressys）のレース結果ページ**: 種目に対応カテゴリーがあると AJOCC pt 列を表示し
  `ajocc_pt/as_category` を出す（`cyclox2res_sys/application/controllers/Race.php`）。対応を足すと
  過去の全レースにも列が出る。
- **デスクトップアプリ（cyclox2app）**: 対応一覧でエントリー時の所属チェック（対応カテゴリー非保有は
  エラー表示）と、エントリー CSV の新規選手へのカテゴリー自動付与を行う。
- **ランキングの作り直しは「移動先」しか対象にならない**: バッチはフラグの出走カテゴリーが**現在持つ**
  as_category のランキングだけを作り直す。as_category を A→B に変えたら、A 側（移動元）のランキングは
  別途、A の成績を持つ出走カテゴリーにフラグを立てないと古いまま残る。

### 既知事項（2026-11-24 時点）
- 対応未登録のまま残っている UCI 種目: `UCIMU` / `UCIWM` / `UCIMM` / `UCIWY` / `UCIMY`
  （AJOCC ポイント付与ありでの使用実績なし）。
- ランキングを作り直していない過去シーズン: 2023-24 JPN-234-002（UCIWJ 2件。as_category のみ WJ に是正。
  2名は当時 WJ 非保有なので、仮に作り直しても WJ ランキングには載らず空の大会列が増えるだけ）、
  2016-17 UCX-167-002（UCIMJ、未是正）。
- 2019 JPN-190-002（UCIWJ、ポイント付与なし）はレース結果ページで「0pt/UCIWJ」と表示される（未是正）。

## この用語集が生まれた経緯
`jcx-lineage-lock-2026-27` spec の系統判定バグ調査（2026-08-29）で、実DBダンプ
（`tmp/20260613_dump.sql`）を用いてこれらのテーブルを裏取りした際に整理した。
