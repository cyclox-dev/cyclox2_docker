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
