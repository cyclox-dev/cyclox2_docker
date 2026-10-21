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
