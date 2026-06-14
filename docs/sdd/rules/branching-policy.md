# ブランチ・PRポリシー（Branching Policy）

## 基本ルール

**`main` ブランチへのファイル修正の直接コミットは禁止。**
いかなる変更も必ずブランチを切ってから行い、PR を経由して `main` にマージする。

---

## 作業フロー

```
作業開始
  │
  ▼
【1】ブランチを作成
  git checkout -b <branch-name>
  （例: feat/add-calc-rule, fix/css-layout, docs/update-readme）
  │
  ▼
【2】作業・コミット
  ファイルを修正 → git add → git commit
  │
  ▼
【3】コミットのたびに確認
  ★ 「これで全コミットが完了ですか？」を人間に確認する
  │
  ├── まだある → 【2】に戻る
  │
  └── 完了 ↓
  │
  ▼
【4】push して PR 発行
  git push -u origin <branch-name>
  gh pr create ...
```

---

## ブランチ命名規約

| prefix | 用途 |
|---|---|
| `feat/` | 新機能 |
| `fix/` | バグ修正 |
| `docs/` | ドキュメントのみの変更 |
| `chore/` | 設定・依存・submodule更新等 |
| `refactor/` | リファクタリング |

---

## 禁止事項

- `git checkout main && git commit` による直接コミット
- サブモジュール更新・`.gitignore` 修正・設定ファイル変更も同様にブランチ経由とする
- `git push --force` （やむを得ない場合は人間に確認）

---

## PR 発行のタイミング

全コミットが完了したことを人間が確認した後に push・PR を発行する。
PR 発行前に `git log --oneline main..<branch>` で差分コミットを提示し、抜け漏れがないか確認する。
