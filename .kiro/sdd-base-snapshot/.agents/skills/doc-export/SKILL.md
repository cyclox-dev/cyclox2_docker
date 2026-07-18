---
name: doc-export
description: Generate human-facing secondary deliverables (PDF / Word / PowerPoint, optionally Excel / diagrams) from the primary Markdown Source of Truth in a spec. Use when the user asks to "export the design as Word/PDF", "二次成果物を出力", "設計書をWord/PDFで出して", "監査用のドキュメントを生成", or to produce audit/share documents from .kiro/specs/<id>/*.md. One-way only (md → view); never edits the primary md.
---

# doc-export — 二次成果物の生成（一次 md → 派生ビュー）

一次成果物（`.kiro/specs/<id>/*.md`、正本）から、人間の検証・共有用の二次成果物
（PDF / Word / PowerPoint、opt-in で Excel・作図）を**一方向で再生成**する。
ルールの詳細は `docs/sdd/deliverables-policy.md` を参照。

## 使うタイミング
- 「この spec の設計書を Word/PDF で出して」「監査用に担当別のドキュメントを生成して」等の依頼。
- レビュー・非開発者への共有のために、正本 md から人間向けフォーマットが欲しいとき。

## 原則（必ず守る）
- **一次(md)が正本。二次成果物は手編集しない**。修正は必ず一次 md を直して再生成する。
- **二次 → 一次の逆変換はしない**（正本を一意に保つ）。
- **正本 `design.md` は物理分割しない**。監査対象別の文書は「節スライス」で出す。
- 出力先: ビルド成果物=リポジトリ直下 `outputs/<id>/`、**PII を含む成果物**=`.kiro/specs/<id>/outputs/`。
  生成時に**出力先を明示**する（PII 隔離時は特にその旨を伝える）。
- レンダラ（pandoc / mermaid-cli / PDF エンジン等）は**同梱していない**。未導入なら「未生成（要 install）」と
  明示し、他の成果物は生成を続ける。取得は `npx -y github:kyamady-dorokid/sdd_base_template install-renderers`。

## 手順（エージェントはこの通り実行する）

1. 対象 spec-id を確認する（例: `two-tier-deliverables`）。
2. 生成したい成果物を「論理成果物 → フォーマット」で決める。必要なら
   `.kiro/specs/<id>/deliverables.manifest` を用意する（無ければ既定=正本全文を Word）。
   - マニフェスト書式（1行1宣言・`#` コメント可）:
     ```
     <source-md>#<section-anchor|*> -> <format> [@pii]
     # 例:
     design.md#API Contract -> docx
     design.md -> pdf
     requirements.md#* -> pptx
     ```
   - `#<section>` は正本内の見出しテキスト。省略／`*` は全文。`@pii` を付けると PII 隔離先へ出力。
3. 生成を実行する（CLI サブコマンド経由。カレントがリポジトリ root であること）:
   ```bash
   npx -y github:kyamady-dorokid/sdd_base_template doc-export <spec-id> [--manifest <path>]
   ```
   - 個人環境にスキルを設置済み（`install`）なら npx 取得は不要（同じサブコマンドがローカルで動く）。
   - 生成ロジック本体は配布パッケージの `payload/scripts/doc-export/export.sh`。ターゲットリポジトリ側へは
     複製しない（cc-sdd 非同梱と同じく、実行はパッケージ経由）。
4. 生成結果（`outputs/<id>/export-report.md`）を人間に提示する。
   「生成済み／未生成（要 install）／エラー（見出し不在等）」を出力先つきで報告する。
5. **自動コミットはしない**。生成物は再生成可能なビルド出力（既定 `.gitignore` 対象）。

## 補足
- 図（ER/クラス/シーケンス）は正本内の Mermaid を `mmdc` で画像化して埋め込む（opt-in）。
- 表主体で編集・進捗管理が要るもの（テーブル定義・テストケース・タスク）は Excel（opt-in・別 pkg）。
- 未導入フォーマットはサイレントに落とさず、必ずレポートに「未生成（要 install-renderers）」と残す。
