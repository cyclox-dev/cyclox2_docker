# Runbook: 2025-26シーズン AJOCC実績レポート データ抽出・検算（Phase 2）

タスクID: `ajocc-report-2025-26`
作成日: 2026-07-02
作成者: Phase 2 作業者エージェント（W2）
目的: レポート再現に必要な全数値をDBから抽出し、24-25シーズンの再現検算（元資料PDF記載値）で抽出ロジックを裏付けた上で、`dataset_2526.json` を数値の唯一の正として作成する。本ファイルは再実行で同じJSONを再現できる粒度でSQLと検算対比を記録する。

## 共通事項

### DB接続
```bash
cd /Users/kyamady/workspace/cyclox2_docker && set -a && source .env && set +a
docker exec -e MYSQL_PWD="$MYSQL_ROOT_PASSWORD" cyclox2_mysql mysql -uroot cyclox2 -N -e "<SQL>"
```
DB名 `cyclox2`、コンテナ `cyclox2_mysql`。

### シーズン日付境界（design.md 決定#2）
- 24-25: `at_date >= '2024-04-01' AND at_date < '2025-04-01'`
- 25-26: `at_date >= '2025-04-01' AND at_date < '2026-04-01'`

### エントリー件数の共通フィルタ
`er.deleted=0 AND ec.deleted=0 AND eg.deleted=0 AND m.deleted=0 AND er.entry_status = 0`（entry_status=0 が有効エントリー）。JCX/ローカル切り分けは `meets.is_jcx`。全日本除外は `m.meet_group_code != 'JPN'`。

### 地域マッピング（design.md、24-25で完全一致検証済み）
CXK→茨城, TYM→北陸, 他は meet_groups.short_name そのまま。JPNは全体集計から除外。

### カテゴリー大分類マッピング（新コード=25-26体系）
- 男子実力別: C1,C2,C3,C4,C3+4,UCIME
- 女子: CL1,CL2,CL3,CL2+3,WJ,WU15,WU17,WM,UCIWE
- 男子14-18歳: CJ,MU15,MU17,UCIMJ
- 男子マスターズ: CM1,CM2,CM3,MM35,MM40,MM45,MM50,MM55,MM60,MM65,MM70,MM75
- 小学生: CK1,CK2,CK3,CK1+2
- その他: CC,SS,Exhibition,Ex

---

## P.3 「1. シーズンまとめ」

### エントリー総数・JCX/ローカル分割
```sql
SELECT m.is_jcx, COUNT(*) FROM entry_racers er
JOIN entry_categories ec ON ec.id=er.entry_category_id
JOIN entry_groups eg ON eg.id=ec.entry_group_id
JOIN meets m ON m.code=eg.meet_code
WHERE er.deleted=0 AND ec.deleted=0 AND eg.deleted=0 AND m.deleted=0 AND er.entry_status=0
  AND m.at_date>='<start>' AND m.at_date<'<end>' AND m.meet_group_code!='JPN'
GROUP BY m.is_jcx WITH ROLLUP;
```
| 指標 | 24-25 再現(生) | 24-25 PDF | 判定 | 25-26 |
|---|---|---|---|---|
| エントリー総数 | 21,268 | 21,268 | **完全一致** | 21,120 |
| JCX(生 is_jcx=1) | 4,137 | 4,018 | 差+119 ※下記 | 4,020 |
| ローカル(is_jcx=0) | 17,131 | 17,250 | 差-119 ※下記 | 17,100 |

**※JCX生値と PDF値の差(119)の理由（多大会統合）**: 24-25の JCX は DBに12大会行あるが、東海CX2は DAY1(2024-11-23, 119件)+DAY2(2024-11-24, 514件)の2行で登録されている。PDF P.8のJCX表は東海(WNP)を DAY2の514のみ1戦としてカウントし DAY1(119)を除外→ JCX=4137-119=4018。よってPDFの JCX/ローカル区分は「is_jcxそのままの生値」ではなく編集上の統合ルールが入る。**エントリー総数(21,268)は完全一致するため、抽出フィルタ自体は正しい**（差はJCX/ローカルの帰属editorial判断のみ）。
- 25-26は is_jcx=1 生値=4,020（13大会行。うち 宇都宮 12/06+12/07、CXT2026 02/07+02/08 が各2日開催→統合後11戦）、ローカル=17,100。test-results.md値と一致。

### アクティブ選手数
```sql
SELECT COUNT(DISTINCT er.racer_code) FROM entry_racers er JOIN ... 同フィルタ（JPN除外・entry_status=0）;
```
| 指標 | 24-25 再現 | 24-25 PDF | 判定 | 25-26 |
|---|---|---|---|---|
| アクティブ選手数 | 3,898 | 3,896 | +2（既知の軽微差） | 3,784 |

### 最大エントリー / 最大同日エントリー
```sql
-- 最大単一大会: GROUP BY m.code ORDER BY COUNT(*) DESC LIMIT 1
-- 最大同日: GROUP BY m.at_date ORDER BY COUNT(*) DESC LIMIT 1
```
| 指標 | 24-25 再現 | 24-25 PDF | 判定 | 25-26 |
|---|---|---|---|---|
| 最大エントリー数 | 983（2025-02-09 関西桂川） | 983（2025/02/09関西桂川） | **一致** | 845（2025-10-19 関西1桂川） |
| 最大同日エントリー | 1,781（2024-12-01） | 1,781（2024/12/1） | **一致** | 1,549（2025-12-21） |

### 開催実績（meets.holding_status: 1=開催, 2=中止）
```sql
SELECT is_jcx, holding_status, COUNT(*) FROM meets
WHERE deleted=0 AND at_date>='<start>' AND at_date<'<end>' AND meet_group_code!='JPN'
GROUP BY is_jcx, holding_status;
```
- 24-25(生): JCX開催行12・ローカル開催行56・ローカル中止1。PDF: 開催予定68(JCX10+ローカル58)/中止1/開催67。生の大会行数はPDFの「戦」数と多大会統合により一致しないが、中止1(信州4, 2024-11-03)はPDF「信州1戦中止」と一致。
- 25-26(生): JCX開催行13(統合後11)・ローカル開催行51・中止行3。中止=信州3(2025-10-25)・信州4(2025-10-26)・もみじ1(2025-09-21)。test-results.md「もみじ第1戦・信州第3・4戦」と一致。
- 25-26 開催予定=JCX11+ローカル54=65戦、中止3、開催62戦（test-results.md準拠）。最大同日開催=5戦(2025-12-21)。

### Web月平均ビュー数
- 実データ未入手。合意#1/#8により仮値100,000（`provisional:true`）。24-25 PDF実値=144,090。


## P.4 「2. 前年度との比較」

3年比較表。元資料P.4は列が `22-23 | 23-24 | 24-25 | 前年度比`。25-26版は列を1年シフトし **`23-24 | 24-25 | 25-26 | 前年度比`**。4ブロック（開催実績/エントリー件数/選手数/Web閲覧数）。JSON格納先=`dataset_2526.json` p4。

### 転記元と算出根拠
- **23-24列・24-25列**: 元資料PDF `tmp/24-25_AJOCC_report .pdf` P.4から直接転記（`col_source: prior_year_fixed`）。元資料の 2023-2024 列・2024-2025 列の値をそのまま持ち込む。
- **25-26列**: 当年DB集計値。既存JSONの p3（開催実績/エントリー件数/選手数）および p5a.row_2526（平均エントリー数=全体avg 340.6→341）から取得（`col_source: db`）。
- **前年度比 = 25-26列 − 24-25列**（`yoy_delta`）。

### 各ブロックの主な値（23-24 / 24-25 / 25-26 / 前年度比）
- 開催実績: 開催予定数 69/68/65/-3、中止数 2/1/3/+2、開催数 67/67/62/-5、最大同日開催数 5/4/5/+1。
- エントリー件数: 総数 21,622/21,268/21,120/-148、JCX 3,570/4,018/4,020/+2、ローカル 18,052/17,250/17,100/-150、平均エントリー数 323/317/341/+24、最大エントリー数 891/983/845/-138、最大同日 1,648/1,781/1,549/-232。
- 選手数: アクティブ 4,010/3,896/3,784/-112（24-25列はPDF転記値3,896。DB検算値は3,898だが比較は転記値基準）、新規参加者 774/734/692/-42（差の既知注記はP.13/論点H）、平均エントリー回数 5.5/5.6/5.6/±0。
- Web閲覧数: 月平均ビュー数 129,751/144,090/**100,000（仮）**（合意#1、`col_source: provisional`）。前年度比は仮値差引-44,090で暫定。実データ入手後に差し替え。

## P.5A 「3. AJOCC エントリー数推移（年度別×シリーズ区分）」

当年度(25-26)行のみDB集計。過去年度は元資料PDF転記(prior_year_fixed)。大会数=多大会統合後。ME1=C1+UCIME。
25-26行: JCX[11, 4,020, 365.5, 930, 84.5] / ローカル[51, 17,100, 335.3, 2,054, 40.3] / 全体[62, 21,120, 340.6, 2,984, 48.1]。
24-25行（整合用DB値）: JCX[10, 4,018, 401.8, 789, 78.9] / ローカル[57, 17,250, 302.6, 1,847, 32.4] / 全体[67, 21,268, 317.4, 2,636, 39.3]（PDF一致）。

## P.5B 「3. 全日本選手権エントリー数推移」

`meet_group_code='JPN'`。25-26全日本=**二色の浜(大阪府貝塚市)・2025-12-13〜14の2日開催**（合意#3は12/14だがDBは2日間登録）。総エントリー484。
カテゴリ内訳: ME(UCIME)67 / MU23(UCIMU)28 / MJ(UCIMJ)19 / MU17=19 / MU15=12 / WE(UCIWE)34 / WJ(UCIWJ)4 / WU17=5 / WU15=4 / MM(MM35-70合算)223 / WM=17 / SS(併催)52 → 計484。
**新コード**: `UCIMU`(U23男子, 28)・`UCIWJ`(女子ジュニア, 4)が全日本で出現（他ページでは未出現）。P.5B専用にME/MU23/MJ等へマッピング。


## P.6 「3. エントリー件数推移：全体と JCX」

**P.5A 時系列データの可視化ページ**（新規DB抽出なし）。JSON格納先=`dataset_2526.json` p6。

### グラフ（P.5Aの可視化）
グラフ用データは全て **p5a**（`p5a.historical` の 2013-2014〜2024-2025 + `p5a.row_2526` の 2025-2026）を参照（p6.`chart_source="p5a"`）。
- 左上「AJOCC大会 エントリー数推移」: 複合グラフ。棒=全体エントリー数＋ME1（積み上げ）、折れ線=大会数（右軸）。系列＝p5a各年の `all`。
- 左下「JCXシリーズ エントリー数推移」: 複合グラフ。棒=エントリー数＋ME1＋WE1（積み上げ）、折れ線=大会数（右軸）。系列＝p5a各年の `JCX`。WE1系列は僅少（元資料P.6のWE1データラベルも小さく、25-26 JCX WE1=181はp8参照）。

### 右側「前年度との比較」3小表
p5a直近2年（24-25=`p5a.historical`末尾行 / 25-26=`p5a.row_2526`）の抜粋＋比較行。JCX/ローカル/全体それぞれ `年度 | 大会数 | エントリー数 | 平均 | ME1 | ME1平均` の3行構成。compare=25-26−24-25（例 全体: エントリー数 21,268→21,120=-148、大会数 67→62=-5、ME1 2,636→2,984=+348）。出所は全てp5a（DB集計）。

### 所見テキスト（当年25-26版に更新）
p6.comments に3点を格納。根拠は本runbook各節の知見:
- JCX は宇都宮UCX新規参入で11戦へ増（P.7=宇都宮374件・P.8多大会統合11戦）。総数はほぼ横ばい。
- ローカルは 21-22 ピーク後の平均エントリー数漸減が継続し、全体総数-0.7%（P.5A/P.4）。
- 地域別は関西の大幅減(-305)を東海(+105)・関東(+54,宇都宮新規含む)・九州(+77)が一部補填（P.7地方ブロック前年度比）。

## P.7 「3. エントリー件数：AJOCC 全体（シリーズ別×カテゴリ）」

### 重要マッピング発見: ME1 / WE1 の新コード対応
DBは24-25も25-26も**新コード体系**で格納されている（24-25も C1-4/CL/CM 等。旧ME1-4等は存在せず、一部 `old_MM40/50/60/MMA` のみ残存）。PDFの「ME1」「WE1」は次で再現できることを24-25検算で確認:
- **ME1 = C1 + UCIME**、**WE1 = CL1 + UCIWE**

### シリーズ別×カテゴリバンド（地域別 ME1/WE1/その他/合計）
```sql
SELECT CASE m.meet_group_code WHEN 'CXK' THEN '茨城' WHEN 'TYM' THEN '北陸' ELSE mg.short_name END AS region,
  SUM(ec.races_category_code IN ('C1','UCIME')) ME1,
  SUM(ec.races_category_code IN ('CL1','UCIWE')) WE1,
  SUM(ec.races_category_code NOT IN ('C1','UCIME','CL1','UCIWE')) other,
  COUNT(*) total
FROM entry_racers er JOIN entry_categories ec ON ec.id=er.entry_category_id JOIN entry_groups eg ON eg.id=ec.entry_group_id JOIN meets m ON m.code=eg.meet_code
LEFT JOIN meet_groups mg ON mg.code=m.meet_group_code
WHERE er.deleted=0 AND ec.deleted=0 AND eg.deleted=0 AND m.deleted=0 AND er.entry_status=0
  AND m.at_date>='<start>' AND m.at_date<'<end>' AND m.meet_group_code!='JPN'
GROUP BY region;
```
**24-25 検算（グランド合計）**: ME1=2,636 / WE1=680 / その他=17,952 / 合計=21,268 → **PDF P.7と完全一致**。16地域の合計も全てPDF一致（関西8333/東海3709/茨城1827/千葉1555/信州1130/東北954/野田827/湘南799/四国567/前橋379/山口330/もみじ305/東京271/中国175/九州76/北陸31）。

**25-26 結果**: ME1=2,984 / WE1=687 / その他=17,449 / 合計=21,120。地域は17（16地域+宇都宮374）。**能登はDBに meet_group も meet も存在せず → 25-26では掲載しない（除外）**。

### 地方ブロック集約
ブロック定義: 関東=茨城(CXK)+千葉(CHB)+野田(MDX)+東京(XTK)+湘南(SHN)+前橋(MBS)+**宇都宮(UCX)** / 中国=もみじ(MMJ)+山口(YGC)+中国(CCH) / 他は単独。
- **24-25検算**: 関東5,658・中国810・関西8,333・東海3,709・信州1,130・東北954・四国567・九州76・北陸31 → **PDF P.7と完全一致**。
- **25-26**: 関西8,028 / 関東5,712 / 東海3,814 / 信州1,143 / 東北969 / 中国625 / 四国594 / 九州153 / 北陸82。前年度比: 東北+15・北陸+51・関東+54(宇都宮新規374含む)・信州+13・東海+105・関西-305・中国-185・四国+27・九州+77。


## P.8 「3. エントリー件数：JCX（大会別×カテゴリ）」

### 新旧コード → PDF報告24カテゴリのマッピング（24-25検算で確定）
| 報告カテゴリ | 新コード合算 |
|---|---|
| ME1 | C1 + UCIME |
| ME2 | C2 |
| ME3 | C3 |
| ME4 | C4 + C3+4 |
| WE1 | CL1 + UCIWE |
| WJ / WU17 / WU15 / WM | 同名 |
| WE2+3 | CL2 + CL3 + CL2+3 |
| CJ | CJ + UCIMJ |
| MU17 / MU15 | 同名 |
| MM1 / MM2 / MM3 | CM1 / (CM2+CM2+3) / CM3 |
| MM35 | MM35 |
| MM40 | MM40 + MM45 |
| MM50 | MM50 + MM55 |
| MM60 | MM60 + MM65 + MM70 + MM75 |
| CK3 / CK2 / CK1 | CK3 / (CK2+CK1+2) / CK1 |
| Ex | Exhibition + CC + SS |

### 多大会統合（25-26 JCX）
- 宇都宮: UCX-256-014(12/06)+UCX-256-015(12/07) → 1大会「宇都宮」374件
- お台場: CHB-256-006(02/07)+CHB-256-007(02/08) → 1大会「お台場」528件
- 東海CX2はDAY2(TKI-256-002, 302件)のみJCXに存在。DAY1は該当なし。
統合後 **11戦**、JCX合計=4,020。

### 24-25検算
24-25 JCXは東海CX2 DAY1(TKI-245-002, 119件)を除外して集計（PDFはWNPをDAY2=514の1戦扱い）。除外後の報告カテゴリ合計:
ME1=789(C1 715+UCIME 74), ME2=396, ME3+ME4=859(C3 318+C4 522+C3+4 19; PDFはME3=320/ME4=539に内訳分割=合計859で一致), WE1=166(CL1 150+UCIWE 16), WE2+3=89(CL2 11+CL3 15+CL2+3 63), WM=35, CJ=70(CJ 58+UCIMJ 12), MU17=60, MU15=61, MM1=58(CM1), MM2=67(CM2), MM3=75(CM3), MM35=44, MM40=260, MM50=577, MM60=179, CK3=56, CK2=73, CK1=54, Ex=18, WJ=2, WU17=19, WU15=11 → **PDF P.8合計行と一致**（C3+4の19件のME3/ME4振り分けのみPDF編集判断で再現不可、合計は一致）。

### 25-26 結果（報告カテゴリ・JCX合計行）
ME1=930, ME2=363, ME3=315, ME4=492, WE1=181, WE2+3=77, WM=47, WJ=13, WU17=22, WU15=10, CJ=78, MU17=75, MU15=44, **MM1=0, MM2=0, MM3=0**（25-26のJCXマスターズは全て年齢帯MM35-65コードで、旧CM1-3相当の登録なし＝構造変化）, MM35=46, MM40=245, MM50=641, MM60=222, CK3=67, CK2=75, CK1=63, Ex=14 → 合計4,020。
per-meet（11戦）内訳は `dataset_2526.json` p8.meets に格納。大会別合計: 茨城1=528, 1亘理=273, 湘南#2御殿場=434, MHCX#12=501, 関西U琵琶GP1=327, 東海CX2=302, 松伏#3=456, 宇都宮=374, 4蔵王=206, YGC#2=91, お台場=528。


## P.9 「3. エントリー件数：ローカル大会（地域別実数+平均）」

```sql
SELECT CASE m.meet_group_code WHEN 'CXK' THEN '茨城' WHEN 'TYM' THEN '北陸' ELSE mg.short_name END AS region,
  COUNT(DISTINCT m.code) meets,
  SUM(ec.races_category_code IN ('C1','UCIME')) ME1,
  SUM(ec.races_category_code IN ('CL1','UCIWE')) WE1,
  SUM(ec.races_category_code NOT IN ('C1','UCIME','CL1','UCIWE')) other,
  COUNT(*) total
FROM entry_racers er JOIN entry_categories ec ON ... 同フィルタ AND m.is_jcx=0
GROUP BY region;
```
### 24-25検算
DBの is_jcx=0 集計: ME1合計=1,847 / WE1合計=514 / 合計=17,131。PDF P.9: ME1=1,847 / WE1=514 / その他=14,889 / 合計=17,250。**ME1・WE1は完全一致**。合計の差119は東海CX2 DAY1(119件)がDB上is_jcx=1だがPDFではローカルに計上される編集判断による（P.8のJCX差119と表裏一体。総数21,268は一致）。
### 25-26結果（is_jcx=0、平均=合計/大会数）
| 地域 | 大会数 | ME1 | WE1 | その他 | 合計 | 平均 |
|---|---|---|---|---|---|---|
| 関西 | 11 | 809 | 322 | 6570 | 7701 | 700.1 |
| 東海 | 7 | 338 | 55 | 3119 | 3512 | 501.7 |
| 信州 | 7 | 244 | 26 | 873 | 1143 | 163.3 |
| 茨城 | 3 | 154 | 17 | 788 | 959 | 319.7 |
| 前橋 | 3 | 104 | 14 | 495 | 613 | 204.3 |
| 四国 | 3 | 78 | 25 | 491 | 594 | 198.0 |
| 湘南 | 2 | 71 | 8 | 433 | 512 | 256.0 |
| 東北 | 3 | 93 | 15 | 382 | 490 | 163.3 |
| 東京 | 1 | 0 | 0 | 410 | 410 | 410.0 |
| 千葉 | 1 | 55 | 9 | 333 | 397 | 397.0 |
| もみじ | 4 | 38 | 3 | 222 | 263 | 65.8 |
| 九州 | 2 | 20 | 2 | 131 | 153 | 76.5 |
| 中国 | 1 | 16 | 6 | 129 | 151 | 151.0 |
| 山口 | 2 | 19 | 3 | 98 | 120 | 60.0 |
| 北陸 | 1 | 15 | 1 | 66 | 82 | 82.0 |
| 合計 | 51 | 1854 | 506 | 14540 | 17100 | 335.3 |
（宇都宮はJCX扱いのためローカル表には出ない。能登なし）


## P.10 「3. エントリー件数：カテゴリー別（大分類）」

大分類マッピング（entry_count、JPN除外）: 男子実力別=C1-4/C3+4/UCIME、女子=CL1-3/CL2+3/WJ/WU15/WU17/WM/UCIWE、男子14-18=CJ/MU15/MU17/UCIMJ、マスターズ=CM1-3/CM2+3/MM35-75/old_MM*、小学生=CK1-3/CK1+2、その他=CC/SS/Exhibition/Ex。

### 表1 エントリー数（実数）
**24-25検算（JCX）**: 男子実力別2,044(PDF一致) / 女子326(PDF322,+4) / 男子14-18=191(一致) / マスターズ1,375(PDF1,260,+115) / 小学生183(一致) / その他18(一致)。女子+4・マスターズ+115の差=東海CX2 DAY1(119件)。PDF P.10 JCXはDAY1除外値=合計4,018。エントリー総数は一致。
**25-26結果**:
| 分類 | JCX | ローカル | 合計 |
|---|---|---|---|
| 男子実力別 | 2,100 | 7,320 | 9,420 |
| 女子 | 350 | 1,148 | 1,498 |
| 男子14〜18歳 | 197 | 545 | 742 |
| 男子マスターズ | 1,154 | 6,605 | 7,759 |
| 小学生 | 205 | 1,373 | 1,578 |
| その他 | 14 | 109 | 123 |
| 合計 | 4,020 | 17,100 | 21,120 |
JCX割合: 52.2/8.7/4.9/28.7/5.1/0.3。ローカル割合: 42.8/6.7/3.2/38.6/8.0/0.6。

### 表2 参加者数（大分類別・延べ）
DBで「大分類ごとの distinct racer_code」を集計（延べ＝1選手が複数大分類にまたがると重複計上）:
25-26: 男子実力別1,749 / 女子295 / 男子14-18=150 / マスターズ1,337 / 小学生365 / その他116（延べ計4,012）。
**注意（論点I・Phase 3引き継ぎ）**: 元資料P.10表2はユニーク選手を1大分類へ代表割当した値（24-25 PDF: 1,788/304/19/1,341/352/0=3,804）で、DBの「大分類別distinct（延べ）」とは定義が異なる（特に男子14-18歳・その他）。代表割当ロジックは元資料に記載がなく厳密再現不可。JSONには延べ値を格納し `assignment:"overlap_distinct"` と明示。アクティブ選手ユニーク総数は3,784（P.3/P.11）。


## P.11 「4. 参加者数：カテゴリー別推移（個別コード）」

各報告カテゴリ（P.8同マッピング）ごとに `COUNT(DISTINCT racer_code)`＝参加者、`entries/participants`＝平均エントリー回数。前年度比は同ロジックで24-25を再集計して差分。**24-25側はマスターズが `old_MM40/50/60/MMA` コードのため、prev集計ではこれらを MM40/MM50/MM60 に含めて前年度比を正しく算出**（初回は old_MM* を Ex に落として誤差が出たため修正）。
```sql
SELECT <報告カテゴリCASE> rc, COUNT(DISTINCT er.racer_code) p, COUNT(*) e
FROM ... 同フィルタ(JPN除外) GROUP BY rc;
```
### 25-26結果（報告カテゴリ・参加者/前年度比/平均エントリー回数）
ME1 356/+28/8.4, ME2 381/-24/5.3, ME3 406/-13/4.1, ME4 891/-19/3.1, WE1 100/±0/6.9, WJ 4/+3/3.8, WU17 8/-1/8.2, WU15 8/+2/5.2, WE2+3 184/-10/3.3, WM 33/-1/2.3, CJ 33/-17/5.5, MU17 75/+16/4.5, MU15 42/-17/5.3, MM1 218/-18/8.6, MM2 378/+20/4.9, MM3 488/-51/4.0, MM35 32/-1/1.9, MM40 127/-56/2.7, MM50 320/-35/3.4, MM60 148/-21/4.0, CK3 102/-1/4.7, CK2 125/+9/4.3, CK1 140/-15/4.0, Ex 116/+19/1.1。
セグメント別ボリューム（延べdistinct）: 男子実力別2,034 / 女子337 / 男子14-18=150 / マスターズ1,711 / 小学生367 / その他116。ユニークactive総数=3,784（前年3,898、-114）。全体平均エントリー回数5.6。
**注**: 個別カテゴリの参加者を単純合算するとセグメント内の選手重複で延べになる。ユニーク総数(3,784)＝P.3/P.10のactive。25-26 JCXマスターズにCM1-3登録がなくローカル主体のため MM1-3(旧CM相当)はローカルで発生。


## P.12 「4. 参加者数：参考資料（年齢分布）」

distinct active racer を性別（racers.gender: 0=男/1=女/-1=不明）×年齢帯で集計。年齢=`2025 - YEAR(birth_date)`（シーズン開始年基準）。
```sql
SELECT r.gender, YEAR(r.birth_date), COUNT(DISTINCT r.code)
FROM entry_racers er JOIN ... JOIN racers r ON r.code=er.racer_code
WHERE ...同フィルタ(JPN除外) GROUP BY r.gender, YEAR(r.birth_date);
```
### 24-25検算
gender別distinct: 男3,506 / 女386 / 不明6 = 3,898。PDF P.12: 男3,510 / 女386 / 不明2 = 3,896。**女性386完全一致**、男性±4・不明±4はアクティブ選手数の既知+2差と生年月日欠損の扱い差による軽微差。
### 25-26結果（年齢帯×性別）
| 年齢帯 | 男性 | 女性 |
|---|---|---|
| 4〜10 | 202 | 65 |
| 11〜20 | 382 | 58 |
| 21〜30 | 481 | 50 |
| 31〜40 | 559 | 65 |
| 41〜45 | 382 | 34 |
| 46〜50 | 459 | 38 |
| 51〜55 | 517 | 49 |
| 56〜60 | 275 | 15 |
| 61〜74 | 131 | 10 |
| 不明(生年NULL) | 5 | 0 |
合計: 男3,395 / 女384 / 性別不明5 → **総計3,784（アクティブ選手ユニーク総数と完全一致）**。範囲外(4歳未満/74超)は男2名のみ。


## P.13 「5. 新規参加者数：推移（コホート三角+地域別新規）」

初参戦シーズン判定に一時表を使用（性能対策）:
```sql
CREATE TABLE tmp_first_entry AS
SELECT er.racer_code, MIN(m.at_date) first_date FROM entry_racers er JOIN ...(全期間・JPN含む全大会) GROUP BY er.racer_code;
```
初参戦シーズン=first_dateの4月始まり年度。25-26アクティブ選手をコホート別に集計、地域別新規は「初レースの地域」に帰属。

### コホート（25-26アクティブ選手の初参戦シーズン別）
2015以前783 / 2016:238 / 2017:208 / 2018:210 / 2019:216 / 2020:172 / 2021:265 / 2022:317 / 2023:311 / 2024:372 / **2025:692** → 合計3,784（active一致）。新規参加者割合=692/3,784=**18.3%**。
### 24-25検算
24-25コホート合計=3,898（active一致）。24-25新規(初参戦=24-25)=755。PDF P.13新規=734。差+21（既知の約3%差＝10年超データの削除大会・at_date欠損による初参戦誤判定。エントリー基準採用・注記方針は合意H）。
### 地域別新規（25-26、初レース地域帰属・合計692）
関西168 / 東海111 / 東京79 / 茨城66 / 信州44 / 千葉43 / 四国38 / 東北25 / 野田22 / 湘南22 / 九州21 / 前橋20 / もみじ12 / 中国9 / 山口6 / 北陸5 / **宇都宮1**。合計692（新規総数と一致）。
### 地方ブロック集約（新規）
関東253(茨城+千葉+野田+東京+湘南+前橋+宇都宮) / 関西168 / 東海111 / 信州44 / 四国38 / 中国27(もみじ+山口+中国) / 東北25 / 九州21 / 北陸5。
**能登**: 地域として存在しないため P.13でも列なし（論点B/N解消）。宇都宮は関東ブロックへ集約（論点N）。


## P.14 「6. AJOCC Web 閲覧数（ページビュー推移表）」

**決定#8・#10によりプレースホルダ**（見出し番号は目次に合わせ「6. AJOCC Web 閲覧数」に整合＝元資料の「8.」バグ修正）。JSON格納先=`dataset_2526.json` p14（`placeholder:true`）。

- Web解析（Google Analytics等）の25-26実データが未入手のため、元資料P.14の**23行の階層構造（親/子）と列見出しのみ**をJSONに保持し、値（`y2324`/`y2425`/`y2526`/`yoy_pct`）は全て `null`＝**TBD（実データ入手後更新）**。
- 行ラベル（親/子）: トップページ / リザルト（一覧・大会ごと・過去） / ランキング（一覧・今季・過去・説明） / カレンダー（一覧・大会ごと・過去） / 選手検索 / 選手データ / 概要（トップ・競技規則・シクロクロスとは?・その他） / ニュース（一覧・記事・過去） / Partners / このサイトについて / その他 / **total**（計23行=末尾totalを含む）。
- 集計期間ラベル（元資料は 2024/9/1〜2025/3/31）も実データ入手後に確定（`period_label: null`）。所見テキスト（元資料5点）も実データ入手後に執筆（`comments: []`）。

## P.15 「6. AJOCC Web 閲覧数（ランキング4表）」

**決定#8・#10によりプレースホルダ**。JSON格納先=`dataset_2526.json` p15（`placeholder:true`）。

- 4表（**ランキングTop10 / リザルトTop10 / 概要Top5 / ニュースTop5**）の**表タイトルと列構成（順位 / ページタイトル / ビュー）のみ**保持。各表の行データは `null`＝**TBD（実データ入手後更新）**。
- Web解析実データが未入手のため、仮値では中身を構成できず（合意#1・design.md）、空箱プレースホルダとする。物理15ページ構成は維持（決定#7）。

---

## 特記事項サマリー

- **能登の扱い**: DBに `meet_group` も `meet` も存在せず、25-26では掲載しない（**除外**）。P.7（AJOCC全体）・P.13（新規参加者）で不在を確認済み。24-25元資料の円グラフ/新規表には能登があったが、25-26は地域列そのものを設けない。
- **宇都宮の扱い**: 地域コード `UCX`。**25-26からJCXへ新規参入**（374件）。多大会統合により 12/06（UCX-256-014）+12/07（UCX-256-015）を1大会「宇都宮」に統合。地方ブロック集約では**関東**へ集約（茨城+千葉+野田+東京+湘南+前橋+宇都宮）。P.5/P.7/P.8/P.13の25-26版に反映済み。
- **未知カテゴリーコード**: `UCIMU`（U23男子、全日本28件）・`UCIWJ`（女子ジュニア、全日本4件）が **P.5B 全日本でのみ**出現（他ページでは未出現）。P.5B専用に MU23/WJ 等へマッピング。また 24-25側はマスターズが `old_MM40/old_MM50/old_MM60/old_MMA` コードで残存しており、P.11の前年度比算出時にこれらを MM40/MM50/MM60 に含める補正が必要（初回は old_MM* を Ex へ誤落としし差が出たため修正済み）。
- **多大会統合の適用箇所**: 25-26 JCXでは、宇都宮（UCX-256-014 + UCX-256-015）とお台場（CHB-256-006 + CHB-256-007）を各1大会に統合。東海CX2は DAY2（TKI-256-002, 302件）のみJCXに存在（DAY1該当なし）。→ **統合後 JCX 11戦**、JCX合計4,020件。24-25側は東海CX2 DAY1（TKI-245-002, 119件）を除外してPDF値（JCX=4,018）と整合させる編集判断が入る（エントリー総数21,268は生値でも完全一致）。

---

## Phase 2b データ改修（2026-07-02・第2稿）

第1稿レビューNG（承認ゲート③差し戻し・agreement-log 決定#12/第2稿プラン）を受け、6項目のデータ改修を実施。**数値の唯一の正は引き続き `dataset_2526.json`**。本節は再実行できる粒度でSQL・結果・是正内容を記録する。DB接続は本runbook冒頭「共通事項」と同一。

### P.11 WE2/WE3分離（従来WE2+3の1行を2行へ）
- 目的: 第1稿NG指摘「WE2とWE3を別カテゴリで集計（WE2+3コードはWE2に含める）＋但し書き」。元資料P.11も別行。
- マッピング: **WE2 = CL2 + CL2+3**（合算コードCL2+3はWE2側に含める）、**WE3 = CL3**。
```sql
SELECT
  SUM(ec.races_category_code IN ('CL2','CL2+3')) AS we2_entries,
  COUNT(DISTINCT CASE WHEN ec.races_category_code IN ('CL2','CL2+3') THEN er.racer_code END) AS we2_participants,
  SUM(ec.races_category_code = 'CL3') AS we3_entries,
  COUNT(DISTINCT CASE WHEN ec.races_category_code = 'CL3' THEN er.racer_code END) AS we3_participants
FROM entry_racers er
JOIN entry_categories ec ON ec.id=er.entry_category_id
JOIN entry_groups eg ON eg.id=ec.entry_group_id
JOIN meets m ON m.code=eg.meet_code
WHERE er.deleted=0 AND ec.deleted=0 AND eg.deleted=0 AND m.deleted=0 AND er.entry_status=0
  AND m.at_date>='2025-04-01' AND m.at_date<'2026-04-01' AND m.meet_group_code!='JPN';
```
- 結果（25-26）: WE2=参加者147/entries493/平均3.4（前年145→+2）、WE3=参加者62/entries119/平均1.9（前年74→-12）。
- 整合: entriesは 493+119=612 = 従来WE2+3統合entries と一致。**参加者は 147+62=209 > 統合distinct 184**（女子選手はWE2とWE3の両方に出場する重複があるため単純合算は延べになる）。総計3,784は不変（分離は内訳のみ）。女子行の並びは元資料P.11順（WE1/WJ/WU17/WU15/WE2/WE3/WM）。

### P.13-A コホート三角の列ズレ是正（本Phase 2bの主眼）
- 症状（第1稿の不整合）: `p13.cohort` の 2025-2026 行が `cells=[null(2014以前), 783(15-16), 238, …]`、continuation_row で 15-16 コホート=783/1534=**51%**。24-25報告の 15-16 継続率 14% からの急騰は非現実的（コホートは減る一方）でサニティチェック違反。
- **根本原因（DB地平線の制約）**: 当DB(cyclox2)の最古エントリーは **2015-09-12** で、`first_date < '2015-04-01'` の選手は **0件**（下記SQLで確認）。したがってDBの最古参バケット（`first_date < '2016-04-01'`）は、元資料PDFが分離している『2014以前』と『15-16』を **分離できない合算値**になる。旧稿はこの合算バケット(783)を丸ごと『15-16』列（列index=1）へ充当し『2014以前』(index=0)をnullにしていた（列ズレ＋2014以前空）。
```sql
-- (1) tmp_first_entry: 全期間・全大会(JPN含む)・deleted=0・entry_status=0 での初参戦日
DROP TABLE IF EXISTS tmp_first_entry;
CREATE TABLE tmp_first_entry AS
SELECT er.racer_code, MIN(m.at_date) first_date
FROM entry_racers er
JOIN entry_categories ec ON ec.id=er.entry_category_id
JOIN entry_groups eg ON eg.id=ec.entry_group_id
JOIN meets m ON m.code=eg.meet_code
WHERE er.deleted=0 AND ec.deleted=0 AND eg.deleted=0 AND m.deleted=0 AND er.entry_status=0
GROUP BY er.racer_code;
ALTER TABLE tmp_first_entry ADD INDEX(racer_code);

-- (2) DBの最古データ確認 → MIN=2015-09-12, first_date<2015-04-01 は0件
SELECT MIN(first_date), MAX(first_date) FROM tmp_first_entry;                 -- 2015-09-12 / 2026-03-15
SELECT COUNT(*) FROM tmp_first_entry WHERE first_date < '2015-04-01';         -- 0

-- (3) 25-26アクティブ選手(JPN除外・entry_status=0・distinct=3,784)を初参戦シーズンで季節バケット
SELECT bucket, n FROM (
  SELECT CASE
      WHEN fe.first_date < '2015-04-01' THEN '00_2014以前'
      WHEN fe.first_date < '2016-04-01' THEN '01_15-16'
      WHEN fe.first_date < '2017-04-01' THEN '02_16-17'
      WHEN fe.first_date < '2018-04-01' THEN '03_17-18'
      WHEN fe.first_date < '2019-04-01' THEN '04_18-19'
      WHEN fe.first_date < '2020-04-01' THEN '05_19-20'
      WHEN fe.first_date < '2021-04-01' THEN '06_20-21'
      WHEN fe.first_date < '2022-04-01' THEN '07_21-22'
      WHEN fe.first_date < '2023-04-01' THEN '08_22-23'
      WHEN fe.first_date < '2024-04-01' THEN '09_23-24'
      WHEN fe.first_date < '2025-04-01' THEN '10_24-25'
      ELSE '11_25-26' END AS bucket,
    COUNT(DISTINCT a.racer_code) AS n
  FROM (
    SELECT DISTINCT er.racer_code FROM entry_racers er
    JOIN entry_categories ec ON ec.id=er.entry_category_id
    JOIN entry_groups eg ON eg.id=ec.entry_group_id
    JOIN meets m ON m.code=eg.meet_code
    WHERE er.deleted=0 AND ec.deleted=0 AND eg.deleted=0 AND m.deleted=0 AND er.entry_status=0
      AND m.at_date>='2025-04-01' AND m.at_date<'2026-04-01' AND m.meet_group_code!='JPN'
  ) a JOIN tmp_first_entry fe ON fe.racer_code=a.racer_code
  GROUP BY bucket
) t ORDER BY bucket;
```
- バケット結果（25-26）: 2014以前=**0**, 15-16=**783**, 16-17=238, 17-18=208, 18-19=210, 19-20=216, 20-21=172, 21-22=265, 22-23=317, 23-24=311, 24-25=372, 25-26=**692**。合計 **3,784**（active一致）、新規割合 692/3,784=**18.3%**。
- **最古バケットの内訳検証**: 783 のうち **754** が `first_date` 2015-10以降（DB開始直後の窓）＝DB以前から活動していた既存選手が大半、残 29 のみ。**24-25検算**でもDB最古バケット=**856** ≒ PDF(『2014以前』751 + 『15-16』216 = 967) − 削除/at_date欠損の目減り。よってDB最古バケットは元資料の『2014以前＋15-16』相当で、DBでは両者を分離不能と確定。
- **是正内容**（`p13.cohort` のみ変更・他は不変）:
  - cohort行 2025-2026: 最古参バケット783を **『2014以前』列(index=0)** に配置し、**『15-16』列(index=1)=null**（DBで真の2015-2016単独コホートを分離できないため）。16-17〜24-25は各自の列へ、25-26=692。合計3,784維持。→ これは「列を1つずらす」是正ではなく、**DB地平線の意味に合わせて最古バケットを正しい列（2014以前）へ帰属**させる是正。
  - continuation_row（各コホートの2025-2026残存÷初年度人数）:
    - initial（各コホート初年度＝元資料P.13対角）: 15-16=1534, 16-17=1506, 17-18=1222, 18-19=1147, 19-20=1141, 20-21=706, 21-22=891, 22-23=1001, 23-24=774, 24-25=734。
    - 継続率 = round(remaining_2526/initial×100)。**式は24-25検算で確認済**（remaining_2425/initial が元資料の継続者割合行 14/15/16/20/20/29/35/39/52% を全列再現）。
    - 是正後: 2014以前=null（元資料同様対象外・initial未定義）、**15-16=null（remaining分離不能・旧51%を撤回）**、16-17=16%（参考・reliable:false）、17-18=17%（参考・reliable:false）、18-19=18%、19-20=19%、20-21=24%、21-22=30%、22-23=32%、23-24=40%、24-25=51%（以上reliable:true）、25-26=null（当年=新規）。
  - **サニティチェック（remaining_2526 ≤ remaining_2425）結果**: 18-19〜24-25は全て単調性を満たす(OK)。**16-17(238>229)・17-18(208>193)** はDB地平線の境界影響で前年をわずかに上回るため参考値扱い(reliable:false)。旧稿で唯一の重大違反だった **15-16(783>216)** は最古バケット合算の誤充当が原因で、上記是正により解消。

### P.13-B 年×地域の新規参加者表（決定#12順・能登→北陸差替）
- 目的: 第1稿NG「Table B＝行=年度・列=地域」を正しい構造で再構成。列順は決定#12（北→南西・宇都宮あり・能登なし）。
- 25-26行はDB集計（初レースの地域へ帰属・合計692）。過去年(2019-20/2022-23/2023-24/2024-25)は元資料P.13下表転記(prior_year_fixed)。能登列は25-26版で落とすが過去行のtotalは能登含むPDF値を保持（`noto_included_in_total`）。
```sql
-- 25-26新規(初参戦=25-26)の初レース地域帰属。tmp_first_entryで初参戦日を持つ選手のうち first_date>=2025-04-01 を新規とし、
-- その選手の25-26最初の大会の地域に帰属。
SELECT CASE m.meet_group_code WHEN 'CXK' THEN '茨城' WHEN 'TYM' THEN '北陸' ELSE mg.short_name END AS region,
  COUNT(DISTINCT er.racer_code) AS new_participants
FROM entry_racers er
JOIN entry_categories ec ON ec.id=er.entry_category_id
JOIN entry_groups eg ON eg.id=ec.entry_group_id
JOIN meets m ON m.code=eg.meet_code
LEFT JOIN meet_groups mg ON mg.code=m.meet_group_code
JOIN tmp_first_entry fe ON fe.racer_code=er.racer_code AND fe.first_date>='2025-04-01'
WHERE er.deleted=0 AND ec.deleted=0 AND eg.deleted=0 AND m.deleted=0 AND er.entry_status=0
  AND m.at_date>='2025-04-01' AND m.at_date<'2026-04-01' AND m.meet_group_code!='JPN'
GROUP BY region;
```
- 結果（25-26新規・地域別）: 関西168 / 東海111 / 東京79 / 茨城66 / 信州44 / 千葉43 / 四国38 / 東北25 / 野田22 / 湘南22 / 九州21 / 前橋20 / もみじ12 / 中国9 / 山口6 / 北陸5 / 宇都宮1 = **692**。地方ブロック集約: 関東253(宇都宮+前橋+茨城+千葉+野田+東京+湘南) / 関西168 / 東海111 / 信州44 / 四国38 / 中国27(中国+もみじ+山口) / 東北25 / 九州21 / 北陸5。前年度比=25-26−24-25（北陸は24-25能登→北陸差替のため25-26実数を暫定表示）。※P.13-Bの数値自体は本Phase 2bで再検証し妥当と判定、書き換えなし（列順・構造のみ第2稿で整備済）。

### P.12 1歳刻みヒストグラム用データ
- 目的: 第1稿NG「ヒストグラムは年齢帯でなく1歳刻みで描画（表は現状維持）」。
- 年齢=`2025 - YEAR(birth_date)`。対象=25-26アクティブのうち gender∈{0,1} かつ birth_date あり。年齢4〜77の並行配列(ages/male/female)。
```sql
SELECT (2025 - YEAR(r.birth_date)) AS age, r.gender, COUNT(DISTINCT r.code) c
FROM entry_racers er
JOIN entry_categories ec ON ec.id=er.entry_category_id
JOIN entry_groups eg ON eg.id=ec.entry_group_id
JOIN meets m ON m.code=eg.meet_code
JOIN racers r ON r.code=er.racer_code
WHERE er.deleted=0 AND ec.deleted=0 AND eg.deleted=0 AND m.deleted=0 AND er.entry_status=0
  AND m.at_date>='2025-04-01' AND m.at_date<'2026-04-01' AND m.meet_group_code!='JPN'
  AND r.birth_date IS NOT NULL AND r.gender IN (0,1)
GROUP BY age, r.gender ORDER BY age;
```
- 結果: 男合計 **3,390**（=P.12表の男3,395 − 生年NULL 5）、女合計 **384**（表と一致）。除外: 男 birth_date NULL 5 / gender不明(-1) 5（ヒストグラム対象外＝表『不明』行と整合）。年齢帯の表(rows)は不変。※Phase 2bで再検証し妥当、書き換えなし。

### P.8 開催日付の格納（YYYY-MM-DD）＋25-26 JCX確認
- 目的: 第1稿NG「対象JCXが25-26シーズンか確認／日付欄をYYYY/MM/DD(西暦付き)に」。
- 各meetに `date`(YYYY-MM-DD) を付与。統合大会（宇都宮/お台場）は `date`=代表日(DAY1)・`date_range`=[DAY1,DAY2]・`merged_codes` を保持。表示形式(YYYY/MM/DD等)はレンダリング側で整形。
```sql
-- 11戦が全て is_jcx=1・holding_status=1・25-26境界内・JPN除外であることを確認
SELECT m.code, m.at_date, m.is_jcx, m.holding_status, m.meet_group_code
FROM meets m
WHERE m.code IN ('CXK-256-001','TCX-256-001','SHN-256-004','CHB-256-003','KNS-256-012',
  'TKI-256-002','MDX-256-001','UCX-256-014','UCX-256-015','TCX-256-004','YGC-256-002',
  'CHB-256-006','CHB-256-007')
ORDER BY m.at_date;
```
- 結果: 11戦（統合後）全て is_jcx=1・holding_status=1・at_date が 2025-04-01〜2026-03-31 内・meet_group_code≠JPN を確認（`is_jcx_confirmed:true`）。#6 WNPはTKI-256-002(DAY2)のみJCX（DAY1該当なし）。数値は不変、日付メタデータの付与のみ。

### P.5B 各カテゴリ最多エントリー年フラグ
- 目的: 第1稿NG「全日本表で各カテゴリ最多年を網掛けで識別」。元資料P.5Bも網掛け実施済み。
- historical全行(2013〜2024.12) + event_2526(2025二色の浜) の全年から、各カテゴリ列の最多エントリー年を算出し `category_max_year` に格納（描画側が該当セルを網掛け）。
- 結果（最多年）: ME=2015, MU23=2021, MJ=2024.1, MU17=2023, MU15=2024.1, **WE=2025**, WJ=2020, WU17=2024.12, WU15=2024.1, **MM=2025**, **WM=2025**。25-26イベント(二色の浜)で WE(34)/MM(223)/WM(17) が過去最多を更新（タイなし）。24-25時点の最多(WE=2018/33, MM=2024.12/200, WM=2023/14)から更新されたことと整合。数値は不変、最多年フラグの付与のみ。

### 一時表の後始末（任意）
```sql
DROP TABLE IF EXISTS tmp_first_entry;  -- P.13再集計後、不要なら削除可
```
