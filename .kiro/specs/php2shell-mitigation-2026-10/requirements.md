# 要件: PHP2Shell（CVE-2026-109618 / 109619）暫定対策

Tier S（簡潔版）。作業区分は SDD Tier 2（本番設定・セキュリティ）。

## 背景

- 2026-10-21、PHP 本体に未認証RCEの脆弱性2件が公表された（CVSS v4 9.2）。
  - CVE-2026-109618: リクエスト処理中の OOM（memory_limit 到達）後の後片付けで解放済みメモリを使う。主な入口は multipart/form-data の解析。mod_php では通常のフォームPOSTでも成立報告あり。
  - CVE-2026-109619: 前リクエストの解放済み状態が残り、同じワーカーの次リクエストが使う。確認済み経路は session.upload_progress、PHP 8.5 の fatal_error_backtraces、リクエスト単位 ini 設定の警告。
- 修正版は 8.2.35 / 8.3.36 / 8.4.27 / 8.5.12 のみ。本番は次のとおりで、公式修正は無い。

| | cyclox-web 本番 | ressys 本番 | ローカル（両方） |
|---|---|---|---|
| PHP | 5.6.40 | 7.1.12 | 7.3.20 |
| SAPI | Apache + mod_php | Apache + mod_php | Apache + mod_php |
| 設定ファイル | 要確認（事前確認で取得） | `/etc/php.ini` + `/etc/php.d/*.ini` | `/etc/opt/rh/rh-php73/php.ini` + `php.d/` |
| php.conf の php_value | 47〜49行（session.save_handler / save_path / soap.wsdl_cache_dir） | 同左 | なし |

mod_php は公式勧告で完全なRCEが実証された最も危険な構成である。

## 要件

1. 両本番サーバーに、公式勧告の暫定対策（設定）を適用する。
   - `memory_limit = -1`
   - `post_max_size = 8M`、`upload_max_filesize` はそれ未満
   - `session.upload_progress.enabled = 0`
   - `fatal_error_backtraces` は PHP 8.5 専用のため対象外
2. 設定は php.ini 系（起動時に読まれる場所）に置き、`.htaccess` の `php_value`・`ini_set()`・`.user.ini` は使わない。
3. php.conf の `php_value` 3行（リクエスト単位の ini 設定＝109619 の経路③）を php.ini 系へ移し、php.conf 側は無効化する。動作（セッション保存先など）は変えない。
4. Web サーバー層で PHP に届く前に攻撃の入口を絞る。
   - ressys: GET / HEAD 以外を拒否（ressys は POST を使わない）。
   - cyclox-web: multipart はエントリー・リザルトCSV読込と API（`.json`）のみ許可し、それ以外は拒否。
5. 反映は httpd の完全再起動で行い、値は CLI ではなく Web（mod_php）経由で確認する。
6. 既存機能を壊さない: ログイン・セッション維持、CSV読込、計測アプリの API 同期、ressys の閲覧。
7. 切り戻し手順を用意する（設定ファイルの無効化＋再起動のみで戻せること）。
8. ローカル（Docker）にも同じ構成を再現し、テスト先行で検証する（本番手順書の先行作成後、フェーズ2）。
9. 恒久対応（PHP 更新）が必要であることを steering / roadmap に残す。

## 対象外

- PHP 本体の更新・バックポートのビルド（恒久対応として別途検討）。
- アプリコードの改修。
