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

## この用語集が生まれた経緯
`jcx-lineage-lock-2026-27` spec の系統判定バグ調査（2026-08-29）で、実DBダンプ
（`tmp/20260613_dump.sql`）を用いてこれらのテーブルを裏取りした際に整理した。
