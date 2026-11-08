# partner-banners-galfer-rdcx-2026-11 テスト結果

## 2026-11-08 実行結果
| 検証 | 結果 |
|---|---|
| www 本番（https://www.cyclocross.jp/）との直接比較（相対パス画像は絶対URLに正規化） | header `#ptnr_logo_list01` 13件・footer `#ptnr_ftr` 13件とも完全一致 |
| 画像の到達性 | `ptnr_logo_galfer.svg` 200（image/svg+xml）、`ptnr_logo_rdcx.svg` 200（image/svg+xml） |
| 静的プレビュー（変更後の header/footer のバナーブロックを抽出し www の base.css / this_year.css で描画、幅1024） | 26枚すべて画像読込成功。並びは Tannus → GALFER → RDCX → J SPORTS。ヘッダー1行・フッター3段でレイアウト崩れなし（スクリーンショットで目視） |
| 使い捨てコンテナ `ressys_galfer_check`（8082、worktree の header.php/footer.php のみ `:ro` マウント）で `/race/27935` を表示、幅1024 | HTTP 200。ヘッダー13枚・フッター13枚とも画像読込成功、並びは Tannus → GALFER → RDCX → J SPORTS。ヘッダーは13件とも同じ行に収まり（ロゴ高さによる上端差は数pxのみ）、フッターは5・5・3の3段。横スクロールの発生なし（スクリーンショットで目視） |

注: 静的プレビューは Docker 停止中の暫定確認。Docker 起動後にコンテナでの確認を実施した（上表の最終行）。
- 起動時、`cyclox2_mysql` が古い `mysql.sock` / `mysql.sock.lock` / `e8ded8ebc717.pid` の残存で起動に失敗したため、mysqld 停止中にこの3ファイルを削除して `docker start` で復旧した（既知の事象）。

後片付け: プレビュー用のローカル http サーバー停止、`docker rm -f ressys_galfer_check` 実施済み。`cyclox2_mysql` は起動したままにしている。
