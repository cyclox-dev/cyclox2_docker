# test-results

## 2026-10-03 実行結果
| 検証 | 結果 |
|---|---|
| `check_banners.py`（改修前＝RED） | NG: header/footer とも 期待10件/実際11件（TREK・アクトサイク欠落、アミノバイタル・Canyon・田中養蜂場が余分） |
| `check_banners.py`（改修後＝GREEN） | OK: header 10件 / footer 10件、相対パス画像なし |
| `php -l` header.php / footer.php | No syntax errors |
| 画像到達性（10件の src に HTTP GET） | 全件 200（アクトサイクは www の絶対URLで 200） |
| ブラウザでの目視（使い捨てコンテナ `ressys_banner_check` に worktree の header.php/footer.php のみマウント、`http://localhost:8082/meet`、ビューポート幅1024） | OK: ヘッダー10枚・フッター10枚とも画像読込成功（naturalWidth>0）。ヘッダー約106px幅、フッター180px幅（Kabuto/アクトサイクの `logo_size02` は170px）でレイアウト崩れなし。スクリーンショットでヘッダー帯を目視確認。フッターはDOM計測のみ |

## ローカル反映手順（再現用）
- 常駐 `cyclox2ressys_svr` はイメージ内にコードを焼き込み、テンプレートはマウントされない（docker-compose.yml）ため、worktree 変更は反映されない。
- 使い捨てコンテナ（同一イメージ・同一ネットワーク・ポート8082）に、compose と同じ conf 4点＋worktree の `header.php`/`footer.php` を `:ro` マウントして起動。常駐コンテナ・メインチェックアウトは無変更。
- 後片付け: `docker rm -f ressys_banner_check`
