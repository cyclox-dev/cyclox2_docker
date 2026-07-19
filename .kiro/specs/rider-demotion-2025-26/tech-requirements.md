# 技術要件確認: 2025-26シーズン ライダー降格処理

| 項目 | 内容 |
|---|---|
| タスクID | `rider-demotion-2025-26` |
| 作成日 | 2026-06-20 |
| 確認者 | Claude Code / KYamada |

---

## 言語・フレームワーク・ライブラリ

| 項目 | バージョン | 制約・備考 |
|---|---|---|
| DB | MySQL 5.7（コンテナ `cyclox2_mysql`） | dump元が 5.7.23-log。`sumup_json` は TEXT(JSON文字列) |
| 実行手段 | `mysql` CLI（`docker exec`） | アプリ改修なし。SQLのみ |
| 生成スクリプト | bash / SQL | downlist→SQL生成は bash（過去の make_sql.py 相当） |

---

## テスト環境

| 項目 | 内容 |
|---|---|
| テストフレームワーク | なし（DB操作のため SQL 検証クエリで代替） |
| テスト実行コマンド | `docker exec -e MYSQL_PWD cyclox2_mysql sh -c 'mysql -u root cyclox2 < <verify>.sql'` |
| テスト対象範囲 | 降格判定の件数・整合性、二重降格不在、旧所属終了 |
| モック方針 | なし（本番同等ダンプをローカルに復元して実データで検証） |

---

## 既存コードとの結合

| 項目 | 内容 |
|---|---|
| 再利用するモデル・クラス | なし（DB直接操作） |
| 参照する計算済みデータ | `tmp_ajoccpt_racer_sets`（アプリのランキング生成物） |
| 変更が波及するテーブル | `category_racers` のみ（INSERT/UPDATE） |
| DB変更の有無 | 有（`category_racers` への降格レコード） |
| マイグレーション要否 | 不要（スキーマ変更なし） |

---

## 環境固有の制約

| 制約 | 内容 |
|---|---|
| MySQL バージョン制約 | 5.7。JSON関数に頼らず `SUBSTRING_INDEX` で `sumup_json[0]` を抽出 |
| Docker 環境での考慮事項 | SQLはコンテナ `/tmp` にコピーして `SOURCE`、または標準入力で投入 |
| 接続情報 | DB=`cyclox2` / user=`root`。パスワードは `.env` の `MYSQL_ROOT_PASSWORD`（リポジトリに平文を書かない。環境変数 `MYSQL_PWD` 経由で渡す） |
| 文字コード | utf8（`category_code`/`racer_code` は utf8_bin） |

---

## リスク・懸念点

| リスク | 対応策 |
|---|---|
| 出走判定の取りこぼし（UCI/混走） | `category_races_categories` で集計対象 race_category を確認（WE1=CL1+UCIWE） |
| 多重行の二重処理 | 降格UPDATEは当該カテゴリーの全アクティブ行を終了、downlistはDISTINCT |
| 本番との断面ズレ | 本番反映はA案（同SQL適用）。ダンプ取得時点＝ローカル断面で検証 |

---

## 承認

- [x] ClaudeCode が上記内容を確認した
- [x] 人間が技術要件を確認・承認した（2026-06-20）
