# 合意形成記録: PHP2Shell（CVE-2026-109618 / 109619）暫定対策

| 項目 | 内容 |
|---|---|
| タスクID | `php2shell-mitigation-2026-10` |
| 作成日 | 2026-10-22 |
| 作業区分 | SDD Tier S（軽量）／ 検証は Tier 2（tester → reviewer） |

---

## 壁打ち概要

- 2026-10-21 公表の PHP 本体の未認証RCE 2件への対応依頼。本番が旧PHPで公式パッチを当てられないため、提案された暫定設定（memory_limit=-1、post_max_size 8M/32M、session.upload_progress.enabled=0、fatal_error_backtraces=0）で対応する方向。
- 公式（php.net、GHSA-w8hw-w9fx-j79w / GHSA-6wmf-4rv5-p3rp）と Sansec・ma.ttias.be 等で裏取りした。提案4設定は公式勧告と一致。ただし fatal_error_backtraces は PHP 8.5 専用で対象外。
- 本番環境をユーザーが確認（2026-10-22）:
  - cyclox-web: PHP 5.6.40、Apache + mod_php（`LoadModule php5_module`、`SetHandler application/x-httpd-php`）
  - ressys: PHP 7.1.12、Apache + mod_php（`LoadModule php7_module`、`SetHandler application/x-httpd-php`）、php-fpm / php-cgi なし、設定は `/etc/php.ini` + `/etc/php.d/`
  - 両サーバーの php.conf 47〜49行に `php_value`（session.save_handler / session.save_path / soap.wsdl_cache_dir）あり
  - 各アプリの `doc/update_plan` にある「web=PHP 5.x / ressys=PHP 5.3.7」は古い記載だった
- ローカル調査で判明: cyclox2_svr の php.ini マウント先 `/usr/local/etc/php/php.ini` はイメージが読まない（実際は `/etc/opt/rh/rh-php73/php.ini`）。リポジトリの php.ini を書き換えても効かない。

---

## 決定事項

| # | 決定内容 | 決定理由 | 決定日 |
|---|---|---|---|
| 1 | 進め方: ①spec と本番手順書を先に仕上げる → ②ローカル（Docker）で再現・テスト → ③tester → reviewer で検証。本番適用はユーザーが行う | ユーザー指示「まずは１をさきに仕上げる。その後２、３で」 | 2026-10-22 |
| 2 | PHP 設定は php.ini 本体ではなく `/etc/php.d/99-php2shell.ini` に置く | 最後に読まれて上書きでき、切り戻しがファイル無効化だけで済む | 2026-10-22（提案、本書の承認待ち） |
| 3 | php.conf の php_value 3行は php.d へ移し、php.conf 側はコメントアウト | 公式がリクエスト単位設定の除去を推奨（109619 経路③）。値は同一で動作は変わらない | 2026-10-22（提案、本書の承認待ち） |
| 4 | Web サーバー層の遮断を併用（ressys: GET/HEAD 以外拒否、web: 許可URL以外の multipart 拒否） | 両本番とも最も危険な mod_php で、公式修正も無いため設定だけでは心細い | 2026-10-22（提案、本書の承認待ち） |
| 5 | ワーカー使い捨て（`MaxRequestsPerChild 1` ＋ `KeepAlive Off`）を両サーバーに採用 | 109619 のリクエスト跨ぎ全般に効く。性能コストは監視で確認し、問題があればこれだけ切り戻す | 2026-10-22（ユーザー承認） |
| 6 | cyclox-web に `always_populate_raw_post_data = -1` を追加 | 公式勧告に記載は無い推論ベースの追加だが、攻撃者が任意に起こせる早期の E_DEPRECATED を止める。アプリは `$HTTP_RAW_POST_DATA` を使っていない | 2026-10-22（ユーザー承認） |
| 7 | 手順書を PR にして第三者レビューに出す | ユーザー指示 | 2026-10-22 |
| 9 | web の遮断ルールに `RewriteCond %{ENV:REDIRECT_STATUS} ^$` を追加 | ローカル検証で、CakePHP の `.htaccess` による内部リダイレクトの際にルールが再評価され、許可したはずの CSV 読込と API まで 403 になることが判明。承認済み設計の意図（両 URL は通す）を実現するための修正 | 2026-10-22 |
| 10 | web で `Content-Length` が8桁以上の本文を Apache で拒否し、`post_max_size` を 8M から 10M に変更 | ローカル検証で、`post_max_size` を超える POST を受けると PHP がリクエスト開始時に警告を出し、`LimitRequestBody` ではこれを防げないことが判明（109619 が悪用する種類の早い段階の警告）。「残存リスクとして受け入れる」案と比較し、ユーザーが「Apache で弾く」を選択 | 2026-10-22（ユーザー承認） |
| 11 | ローカルの cyclox2_svr の php.ini マウント（`/usr/local/etc/php/php.ini`。イメージが読まない場所）は変更せず、コメントで注記するだけにする | 読み込まれる場所に直すと、リポジトリの php.ini の `extension=pdo_mysql` がイメージの php.d と二重読み込みになり、起動時の警告（それ自体が 109619 の経路③）を生むため。今回の範囲外 | 2026-10-22 |
| 12 | web の Content-Length ルールを「7桁以内の数字だけ許可」に変更 | tester 指摘: `+11000000` で 8桁ルールをすり抜けて PHP が警告を出すことを再現。承認済み（決定10）の意図を実現するための修正 | 2026-10-22 |
| 13 | web の許可 URL を `^/entry_categories/check_result_file/[0-9]+/?$` の完全一致に変更。本番は手順書 0. でフォームの action を確認し、前にパスが付く場合は直す | tester 指摘: 部分一致では任意の URL の後ろに付けてすり抜けられる | 2026-10-22 |
| 14 | ローカルの ressys に、イメージ同梱 ssl.conf（8443番）に Include を足した `ssl-image.conf` をマウント | tester 指摘: 8443 番の VirtualHost に遮断ルールが無い。「各 VirtualHost に Include」という承認済み設計をローカルでも再現するため。リポジトリの既存 `ssl.conf` はマウントされておらず、使うと 443 番待ち受けや証明書パスが変わって起動に影響するため使わない | 2026-10-22 |
| 15 | web で `post_max_size` が現在 10M を超えていたら、本番適用を中止して相談する（手順書 0.） | 決定10・12 のルールは 9,999,999 バイトを超える本文を拒否するため、既存の大きな送信を壊さないよう確認する | 2026-10-22 |
| 16 | web の multipart 遮断から `.json` の例外を削除し、multipart は CSV 読込 URL だけ許可 | reviewer 指摘 M1（どの URL でも末尾を `.json` にすれば multipart が PHP に届く）。ユーザー指示で計測アプリの jar を調べ、API は `Content-Type: application/json` で送り multipart を使わないことを確認（2023年版・2026-02版・2026-09版） | 2026-10-22（ユーザー判断） |
| 17 | ワーカー使い捨ては、処理能力の上限（サーバーごとに毎秒約32接続）を承知のうえで両サーバーに採用を維持。手順書 8. に混雑時の監視（1秒あたりのリクエスト数・応答時間。`seems busy` は標準の LogLevel では記録されないため使わない）を足し、切り戻しは 109619 の主な防御を外すため人間判断とする | reviewer 指摘 B1（上限の存在が決定5の承認時に示されていなかった）と M2（ini では開始時の警告を塞ぎきれず、使い捨てが唯一の実効的な防御）。「計測してから決める」「web だけ」と比較し、ユーザーが「両方そのまま採用」を選択 | 2026-10-22（ユーザー判断） |
| 18 | reviewer の M3・M4・軽微5件を手順書に反映（php_value の実際の値を控えて使う、他の php_value・LimitRequestBody の検出で中止、Include 先の明確化と Include 漏れの確認、7-1 不一致時の全戻し、configtest 失敗時の戻し順、memory_limit 到達件数の事前把握） | 方針を変えない手順の正確化 | 2026-10-22 |
| 19 | reviewer 再レビュー（APPROVED）の非ブロッキング指摘4件は文面修正のみで反映し、追加の検証はしない。あわせて tester 指摘のすり抜け2件（`+` 付き Content-Length、許可 URL の部分一致）の確認を手順書 7-2 に追加 | ユーザー指示（選択肢 a） | 2026-10-22 |
| 8 | 本番の適用前の `memory_limit = 128M`（`/etc/php.ini`）を、恒久対応後に戻す値として記録する。記録先は `99-php2shell.ini` のコメント行、design.md、runbook.md（0. と 10.） | 追加ファイルで上書きすると実効値から元の値が見えなくなるため（ユーザー指示） | 2026-10-22 |

---

## 却下・保留事項

| 内容 | 理由 |
|---|---|
| fatal_error_backtraces=0 | PHP 8.5 専用。対象バージョンに存在しない |
| max_input_vars / max_input_nesting_level の引き下げ | 計測アプリの API が選手配列を一括 POST しており、下げると同期データが黙って切り捨てられる恐れがある。現行値を維持 |
| max_multipart_body_parts | PHP 8.0.29 以降にしか無い |
| `.htaccess` の php_value / `.user.ini` / `ini_set()` で設定する方法 | 公式が無効または逆効果（php_value 自体が 109619 の経路）としている |
| cgroup 等による OS 側のメモリ上限 | web の OS バージョンが未確認（CentOS 6 なら systemd が無い）。まず監視で様子を見る。必要になれば別途検討 |

---

## フェーズゲート承認記録

> 承認状態の正本は本ファイルの本節（Tier S のため spec.json は作らない）。

| フェーズ | 合意メモ（理由・補足） |
|---|---|
| 要件・設計・本番手順書 | 2026-10-22 作成。判断待ち2件（決定5・6）はユーザー承認済み。手順書全体は PR で第三者レビュー中 |
