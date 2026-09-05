# assets/

`build_report.js` が参照する画像アセット置き場。

## ajocc_logo.png

- 出所: ユーザー提供の正式版ロゴ `AJOCC_logo2026.pdf` / `AJOCC_logo2026.ai`（2026-09-05提供、Adobe Illustrator 30.3作成）。
- 作成手順: `pdftocairo -png -r 600 -transp AJOCC_logo2026.pdf` で高解像度・透過PNGへラスタライズし、
  Pillow（`Image.getbbox()`）でワードマーク部分（クラウン+「AJOCC」文字。下部の日本語/英語サブタイトル行は除く）
  を自動クロップして保存。
- アスペクト比: 1665:621（`build_report.js`の`LOGO_ASPECT`定数と一致させること。差し替える場合は要更新）。
- 用途: P.1表紙の大型ロゴ、各ページヘッダー右上の小ロゴ（`logo()`関数）。
- フッターの文字列表記「ＡＪＯＣＣ　一般社団法人日本シクロクロス競技主催者協会」（`footer()`関数）は
  このロゴ画像を使わず、引き続きテキストで描画している（2026-09-05時点、変更依頼の対象外だったため）。
