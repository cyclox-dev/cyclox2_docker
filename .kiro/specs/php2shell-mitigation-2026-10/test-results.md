# テスト結果記録: PHP2Shell 暫定対策（ローカル）

| 項目 | 内容 |
|---|---|
| タスクID | `php2shell-mitigation-2026-10` |
| 実行日 | 2026-10-22 |
| 実行者 | Claude（オーケストレーター） |
| テストフレームワーク | シェルスクリプト（curl / docker exec） |
| 実行コマンド | `verify_local.sh up` → `verify_local.sh test` → `verify_local.sh down` |
| 実行環境 | Docker（使い捨てコンテナ `php2shell_verify_web` / `php2shell_verify_ressys`。常駐コンテナには触れない）。PHP 7.3.20 / Apache 2.4.34 prefork / mod_php |

使い捨てコンテナは docker-compose.yml の各サービスの volumes をそのまま読み取ってマウントする（`verify_local.sh` の `compose_volumes`）。database.php（git 管理外）だけメインチェックアウトのものを読み取り専用で使う。

---

## テスト項目一覧

テストは実装前に `verify_local.sh` に書き、対策前の構成で失敗することを確認してから実装した。

| # | テスト項目 | 期待結果 |
|---|---|---|
| W-INI-1〜6 / R-INI-1〜6 | Web 経由（mod_php）の ini 値 | SAPI `apache2handler`、memory_limit `-1`、post_max_size web `10M` / ressys `8M`、upload_max_filesize `2M`、upload_progress `0`、soap.wsdl_cache_dir が移設前と同値 |
| W-PV / R-PV | httpd 設定に有効な `php_value` / `php_flag` が無い | 0 行 |
| W-MP1〜3 | web: 許可外 URL への multipart（大文字小文字違いを含む） | 403 |
| W-MP4 | web: CSV 読込 URL への multipart | 403 以外（PHP まで届く） |
| W-MP5 / W-MP5b | web: API（.json）・任意 URL＋.json への multipart | 403 |
| W-MP5c | web: 計測アプリと同じ application/json の POST | 403 以外 |
| W-MP13〜15 | web: `+` 付き Content-Length、許可 URL の部分一致・index.php 経由 | 拒否（13 は PHP の超過警告も出ない）/ 403 / 403 |
| R-SSL1〜3 | ressys: 8443 番の VirtualHost | POST・multipart は 403、GET は 200 |
| W-MP6〜7 | web: 通常のフォーム POST・GET 画面 | 403 以外 / 200 |
| W-MP8〜9 | web: Content-Length 11MB（multipart・urlencoded） | 403 または 413（PHP 到達前） |
| W-MP10 | web: chunked で 11MB | 413 |
| W-MP11 | web: ちょうど 10,000,000 バイト（8桁） | 403 |
| W-MP12 | web: 9,999,999 バイト（7桁） | 403 以外（post_max_size 10M 以内で警告なし） |
| W-MPS1〜2 | web: 443 番の VirtualHost でも同じ遮断 | 403 / 403 以外 |
| R-M1〜3 | ressys: POST・multipart・PUT | 403 |
| R-M4〜6 | ressys: GET・HEAD・選手検索（GET フォーム） | 200 |
| W-WK-1 / R-WK-1 | 20 回の連続リクエストの PID | 全て異なる（MaxConnectionsPerChild 1） |
| W-WK-2 / R-WK-2 | HTTP/1.1 応答の Connection ヘッダ | `close`（KeepAlive Off） |
| W-LOG / R-LOG | 全テスト後の error_log | PHP の Warning / Notice / Deprecated / Startup が 0 件 |

---

## 実行結果

### 1回目（RED、対策前の構成）

- 結果: PASS 19 / FAIL 17（想定どおり失敗）。
- 失敗した項目: memory_limit・upload_progress（両方）、php_value 残存（両方）、multipart 遮断、ressys の POST/PUT、KeepAlive、W-LOG。
- W-WK-1 / R-WK-1 は対策前でも合格した（2回の連続リクエストで PID を比べていたため、子プロセスの割り振りだけで別 PID になった）。**20 回で全て異なるかを見るよう強化した**（子プロセス数より多いので、対策前なら必ず重複する）。

### 2回目（対策後、承認済み設計どおり）

- 結果: PASS 34 / FAIL 4。
- **W-MP4・W-MP5・W-MPS2 が失敗（CSV 読込と API まで 403）。** CakePHP の `.htaccess` が `index.php` へ内部リダイレクトするとサーバーレベルの Rewrite が再評価され、`REQUEST_URI` が `/index.php` になるため。`RewriteCond %{ENV:REDIRECT_STATUS} ^$` を追加して修正した（本番の手順書にも反映。agreement-log 決定9）。
- **W-LOG が失敗。** `PHP Warning: POST Content-Length of ... exceeds the limit of 8388608 bytes`。`post_max_size` を超える POST を受けると、mod_php は本文を読む前（リクエスト開始時）に警告を出す。`LimitRequestBody` で 413 を返しても警告は防げなかった。

### 3回目（Content-Length ルール追加後）

- ユーザー判断（agreement-log 決定10）により、web で Content-Length が8桁以上の本文を Apache で拒否し、`post_max_size` を 10M にした。
- 結果: PASS 38 / FAIL 2。W-MP8・W-MP9 が 403 ではなく 413 だった。ルールで拒否した後、Apache が残りの本文を捨てる際に LimitRequestBody に当たって 413 になるため。どちらも PHP 到達前の拒否で、W-LOG（警告 0 件）も合格しているので、テストを「403 または 413」に直した。

### 4回目（最終）

- 結果: **PASS 40 / FAIL 0**。

### tester による独立検証（1回目）と修正

tester（独立コンテキスト）が 40/40 を再現し、ミューテーション3種（REDIRECT_STATUS 条件・Content-Length ルール・ワーカー使い捨ての除去）でテストが失敗することを確認した。そのうえで次の3件を指摘した。

| # | 指摘 | 修正 | 追加テスト |
|---|---|---|---|
| 1 | `Content-Length: +11000000` が 8桁ルール（`^[0-9]{8,}$`）をすり抜け、PHP が開始時に警告を出す | 「7桁以内の数字だけ許可」（`!^$` かつ `!^[0-9]{1,7}$` なら拒否）に変更 | W-MP13 |
| 2 | ressys の 8443 番（SSL）VirtualHost に遮断ルールが入っていない（ポートはホストに非公開） | イメージ同梱の ssl.conf に Include を足した `ssl-image.conf` をマウント | R-SSL1〜3 |
| 3 | 許可 URL の判定が部分一致で、`/racers/index/entry_categories/check_result_file/` でも multipart が PHP に届く | `^/entry_categories/check_result_file/[0-9]+/?$` に固定 | W-MP14・W-MP15 |

修正後の結果: **PASS 46 / FAIL 0**（追加テストを含む）。

### tester による再検証（2回目）

- 46/46 を再現。指摘1〜3がいずれも解消したことを、元の再現手順で確認（`+11000000` で警告 0 件、8443 で POST/PUT/multipart が 403、部分一致・index.php 経由・パス追加が 403、正規の CSV 読込・API は PHP まで届く）。
- Content-Length の追加プローブ（`+5`・`-1`・空・重複ヘッダ・前後の空白・`0005`・`Content-Length: 0`・chunked との併用）で、すり抜けも誤検知も無し。
- 残った指摘（低）: W-MP8・9・13 は応答コード（403/413）だけを見ており、旧ルールに戻しても単体では失敗しない（最後の W-LOG だけが検出）。→ 各テストの前後で `exceeds the limit` の件数を比べる `-LOG` 判定を追加した。旧ルール（`^[0-9]{8,}$`）に戻したミューテーションで W-MP13-LOG が失敗することを確認し、ファイルを元に戻した（チェックサム一致）。
- 修正後の結果: **PASS 49 / FAIL 0**。

### reviewer による独立レビュー（1回目: REJECTED）と対応

- B1（処理能力の上限）・M2（ini では開始時の警告を塞ぎきれない）: ユーザー判断で両サーバーに採用を維持（agreement-log 決定17）。設計書・手順書・steering に上限と、切り戻しが主な防御を外すことを明記し、監視手順を追加。
- M1（`.json` の例外が広すぎる）: 計測アプリの jar を調べて API が `application/json` で送ることを確認し、例外を削除（決定16）。テストを W-MP5（.json への multipart は 403）・W-MP5b（任意 URL＋.json も 403）・W-MP5c（application/json の POST は通る）に変更・追加。
- M3・M4・軽微5件: 手順書を修正（決定18）。
- 修正後の結果: **PASS 51 / FAIL 0**。

### reviewer による再レビュー（2回目: APPROVED）

- ブロッキング指摘なし。非ブロッキングの指摘4件（監視手順の `seems busy` が標準の LogLevel では記録されない、本表の古い行、http→https 転送時の誤判定、VirtualHost 内の既存 LimitRequestBody）を文面の修正で反映した。設定ファイル・テストの変更はなし。

### ミューテーションテスト（Content-Length ルールの必要性）

- `php2shell-rules.inc` の Content-Length の2行を一時的にコメントアウトして実行。
- 結果: PASS 38 / FAIL 2。W-MP11（1000万バイトが 200 で PHP に届く）と W-LOG（`exceeds the limit` の警告 2 件）が失敗した。ルールが無いと警告を防げないことを確認し、元に戻した。
- `REDIRECT_STATUS` の条件は、2回目の実行が「その条件が無い状態」に当たり、W-MP4・W-MP5・W-MPS2 の失敗で必要性を確認済み。

---

## 実行結果サマリー

| 合計 | 合格 | 失敗 | スキップ |
|---|---|---|---|
| 51 | 51 | 0 | 0 |

## 確認できていないこと

- 本番の PHP 5.6 / 7.1、httpd 2.2 の可能性（web）での挙動。ローカルは PHP 7.3・httpd 2.4。mod_rewrite の書き方は 2.2 でも動くものに限定した。
- 本物の SSL（ローカルの 443 番は SSL が無効のまま）。VirtualHost への Include が効くことは平文 HTTP で確認した。
- ログインした状態での CSV 読込と、計測アプリからの実際の同期（結合試験チェックリストで人が確認する）。
- ローカルの web は `error_reporting` が `E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED` のため、W-LOG のうち Notice / Deprecated は出ない（tester 指摘）。開始時の `post_max_size` 超過警告は E_WARNING なので検出できる。本番の `error_reporting` は未確認。
- CVE そのもの（OOM や use-after-free）の再現はしていない。
