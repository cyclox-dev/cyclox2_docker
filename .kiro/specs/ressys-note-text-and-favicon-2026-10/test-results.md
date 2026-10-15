# test-results

## 2026-10-07 実行結果
| 検証 | 結果 |
|---|---|
| `php -l` view.php | No syntax errors |
| 旧文言の残存 grep（application/ 配下） | 0件 |
| 使い捨てコンテナ `ressys_note_favicon_check`（8082、worktree の view.php/header.php のみ `:ro` マウント）で `/race/27935`（もみじ第1戦）を取得 | 「基準順位もう1回で昇格」1件、「あと1回で昇格可能」0件。`<head>` に icon 3行が出力されている |
| ブラウザでの目視（同ページ ME2） | 1位 大浜選手のNote欄に「基準順位もう1回で昇格」と表示。レイアウト崩れなし |
| icon 画像の読込（ブラウザで Image ロード） | favicon.ico OK（48px）、apple-touch-icon.png OK（152px）、favicon.png NG（www側で404・配置依頼済み） |

後片付け: `docker rm -f ressys_note_favicon_check` 実施済み。

## 2026-10-16 追加修正の実行結果
| 検証 | 結果 |
|---|---|
| www 本番（https://www.cyclocross.jp/）との直接比較（相対パス画像は絶対URLに正規化） | header `#ptnr_logo_list01` 11件・footer `#ptnr_ftr` 11件とも完全一致。icon 3行も一致 |
| 画像の到達性 | `ptnr_logo_tannus.svg` 200（image/svg+xml）、`favicon.png` 200（512px） |
| 使い捨てコンテナ `ressys_tannus_check`（8082、worktree の header.php/footer.php のみ `:ro` マウント）で `/race/27935` を表示、幅1024 | ヘッダー11枚・フッター11枚とも画像読込成功。Tannus は diatec と J SPORTS の間。ヘッダーは1行に収まり、レイアウト崩れなし（スクリーンショットで目視） |

後片付け: `docker rm -f ressys_tannus_check` 実施済み。
