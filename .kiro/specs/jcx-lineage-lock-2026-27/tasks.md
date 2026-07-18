# Implementation Plan

> 対象コードベース: `cyclox2_svr/cyclox2/`（submodule cyclox-dev/cyclox2web。ブランチは submodule 側で作成する）
> 前提: me-mm-linkage-2026-27（Wave 1）の `CategoryLineageMap` が実装済みであること。
> 全タスクTDD（テスト先行）。制御強度等の決定点は全件確定済み（agreement-log.md「決定点の確定状況」参照。
> デフォルト=案B 'warn'、警告と回避誘導は強め=Requirement 5 AC7）。

- [ ] 1. 基盤: 設定とテストフィクスチャの整備
- [ ] 1.1 エントリー・大会・シーズン系のテストフィクスチャを整備する
  - Season（2025-26 / 2026-27 の2シーズン、start_date/end_date 付き）、Meet（is_jcx=0/1・
    season_id・at_date のバリエーション）、EntryGroup / EntryCategory / EntryRacer の階層、
    RacesCategory、CategoryRacesCategory（エリート種目・マスターズ種目・系統対象外種目・
    両系統混在種目の対応）を用意する
  - me-mm-linkage-2026-27 が新設する CategoryFixture / RacerFixture は再利用し、重複定義しない
    （未実装の場合のみ本タスクで作成）
  - 完了条件: フィクスチャ群を読み込むスモークテストがグリーンで、is_jcx=1 の大会・両系統の
    種目対応を含むデータがテストDBに展開される
  - _Requirements: 2.1, 2.2_
- [ ] 1.2 運用モード・適用開始シーズンの設定とログ出力先を追加する
  - bootstrap に JcxLineageLock 設定（mode: 'warn'＝確定デフォルト、effectiveFrom: '2026-04-01'）
    を追加し、ログ scope `jcx_lineage_lock` のファイル出力設定を加える
  - mode 未設定・不正値時に 'warn' へフォールバックする読み出し（テスト先行）
  - 完了条件: 設定値の読み出し・フォールバックのユニットテストがグリーンで、当該scopeへの
    ログ書込がファイルに記録される
  - 設定コメントに「デフォルト 'warn' は 2026-07-15 人間承認で確定（agreement-log 決定点#1）」
    と出典を明記する
  - _Requirements: 1.4, 5.1_

- [ ] 2. コア判定ロジック（JcxLineageLock）
- [ ] 2.1 種目（レースカテゴリー）の系統解決を実装する
  - テスト先行: エリート種目 / マスターズ種目 / 対象外種目（女子等）/ 両系統混在種目 /
    カテゴリー紐づけ無し種目 の5系で期待値（elite / masters / null）を定義
  - CategoryLineageMap 公開API（isEliteCategory / isMastersCategory）のみで系統へ写像し、
    category_group_id の直書きをしない。リクエスト内 static メモ化を含む
  - 完了条件: 上記5系のユニットテストがグリーン
  - _Requirements: 2.1, 2.5_
- [ ] 2.2 シーズン固定系統の算出とチェック対象判定を実装する
  - テスト先行: 未エントリー=null / 開催日昇順の先頭選択（同日はエントリーID昇順）/
    取消済（deleted）エントリーの除外 / 非JCX大会・他シーズンの不算入 / exclude 指定
    （meetCode・entryRacerIds）による自己除外 / 適用開始前シーズン（2025-26）の対象外判定
  - isCheckTarget（is_jcx かつ seasons.start_date >= effectiveFrom）と fixedLineage を実装する
  - 完了条件: 上記全ケースのユニットテストがグリーンで、fixedLineage が根拠（大会名・開催日・
    entryRacerId）を返す
  - _Requirements: 1.1, 1.2, 1.3, 2.2, 2.3, 2.4, 2.6, 4.2_
- [ ] 2.3 違反判定（check / checkBulk）と結果オブジェクト・fail-open を実装する
  - テスト先行: 固定系統なし=通過 / 一致=通過 / 不一致=違反明細（選手・固定系統・根拠大会・
    違反系統）/ checkBulk が固定系統算出を IN句1クエリで行う（クエリ回数アサート）/
    判定中の例外で通過+エラーログ（fail-open）
  - JcxLineageCheckResult（イミュータブル値オブジェクト: ok / violations / toApiArray /
    toLogMessage）と mode() を実装する
  - 完了条件: 単体・一括・fail-open・モード読み出しのユニットテストがグリーン
  - _Requirements: 2.2, 3.4, 5.1, 7.3, 7.4, 7.5_

- [ ] 3. モデル層の強制点（保存フック）
- [ ] 3.1 (P) EntryRacer の保存フックを実装する
  - テスト先行: 非JCX大会の保存が無影響（JcxLineageLock のDB問い合わせが発生しない）/
    JCX初回エントリーは通過 / 違反は保存拒否+validationErrors+lastJcxCheckResult 保持 /
    jcxLockOverride=true で通過 / mode=block では override 無効 / racer_code のみの更新
    （選手統合経路）は判定対象外
  - beforeSave で新規・編集（既存行とのマージ）両対応の判定を行い、saveMany / saveAssociated
    経由でも発火することをテストで担保する
  - 完了条件: 上記全ケースのモデルテストがグリーン
  - _Requirements: 3.1, 3.2, 3.5, 5.4, 7.1_
  - _Boundary: EntryRacer hook_
- [ ] 3.2 (P) EntryCategory の種目変更フックを実装する
  - テスト先行: 新規作成・種目以外の更新では発火しない / races_category_code 変更で所属の
    有効選手全員を checkBulk 検証 / 違反者がいれば保存拒否+違反者明細 / override で通過
  - 完了条件: 上記全ケースのモデルテストがグリーン
  - _Requirements: 3.3_
  - _Boundary: EntryCategory hook_

- [ ] 4. 管理画面経路の警告・オーバーライドUX
- [ ] 4.1 EntryRacers（個別登録・編集）の警告表示と確認フローを実装する
  - テスト先行（コントローラテスト）: 違反時に警告（固定系統・根拠大会名/開催日・違反系統・
    対象選手）が表示される / warn モードで確認付き再送信により保存成功しオーバーライドが
    実行者付きでログ記録される / block モードでは確認UIが出ず拒否のみ
  - 共通警告エレメント jcx_lock_warning.ctp を新設し、add / edit 系ビューへ組み込む
  - 完了条件: warn / block 両モードのコントローラテストがグリーンで、オーバーライドログに
    実行者・選手・大会・違反内容・日時が含まれる
  - _Requirements: 3.1, 3.2, 3.4, 5.2, 5.3, 5.4_
  - _Boundary: EntryRacersController, jcx_lock_warning.ctp_
- [ ] 4.2 (P) EntryCategories（種目変更）の警告・確認フローを実装する
  - テスト先行: 種目変更で違反となる選手の一覧が警告表示される / warn モードの確認付き
    再送信で変更が完了し記録される / block モードは拒否のみ
  - 4.1 で作成した警告エレメントを再利用する
  - 完了条件: 種目変更の warn / block 両モードのコントローラテストがグリーン
  - _Requirements: 3.3, 3.4, 5.2, 5.3, 5.4_
  - _Boundary: EntryCategoriesController（edit）_
  - _Depends: 4.1_

- [ ] 5. 一括経路への適用
- [ ] 5.1 (P) 外部API一括エントリー（add_entry）のプリチェックと応答を実装する
  - テスト先行: 違反選手を含む一括登録が既存データの削除前に拒否され、応答に
    jcx_lineage_violations（選手・固定系統・違反系統・根拠大会）が含まれる /
    jcx_lock_override=true かつ warn モードで登録され記録される / block モードでは override
    指定でも拒否 / 同一大会の再アップロードが自大会の旧エントリーと衝突しない（exclude 検証）
  - execAddEntry の削除処理より前に checkBulk を実行する。既存の成功応答形式は変更しない
  - 完了条件: 上記全ケースのAPIテストがグリーン
  - _Requirements: 4.1, 4.2, 5.5, 5.6_
  - _Boundary: ApiController（add_entry）_
- [ ] 5.2 (P) リザルトファイル取込の警告記録（非ブロック）を実装する
  - テスト先行: 違反を含むリザルト取込が完了する（保存はブロックされない）/ 違反明細が
    ログ（経路: リザルト取込、として記録）と取込結果画面の警告に残る
  - saveMany 前に checkBulk を実行し、override 設定+記録のうえ続行する
  - 完了条件: 違反あり取込の完了とログ・画面警告のコントローラテストがグリーン
  - _Requirements: 4.3, 4.4, 5.3_
  - _Boundary: EntryCategoriesController（write_results）_

- [ ] 6. 運用支援
- [ ] 6.1 (P) 違反検出シェル（JcxLineageCheckShell）を実装する
  - テスト先行: 同一シーズンのJCX戦で両系統のエントリーを持つ選手のみが検出される /
    出力に選手識別子・大会名・開催日・各エントリーの系統が含まれる / season 指定・
    省略時（本日が属するシーズン）・不在シーズンのエラー終了
  - `Console/cake jcx_lineage_check detect --season <id>`（`--csv` オプション付き）として実装
  - 完了条件: 検出・出力項目・引数処理のシェルテストがグリーン
  - _Requirements: 6.1, 6.2_
  - _Boundary: JcxLineageCheckShell_

- [ ] 7. 結合検証
- [ ] 7.1 全経路の統合検証と非影響・性能の確認を行う
  - 全ユニット・統合テストスイートを一括実行しグリーンであることを確認する
  - 非JCX大会のエントリー登録・編集・API登録・リザルト取込が機能追加前と同一挙動である
    ことを回帰テストで確認する（7.1）
  - 個別チェックの追加クエリ数（メモ化検証）と checkBulk のクエリ回数（選手数非依存）を
    アサートし、固定系統算出クエリの EXPLAIN を確認する。インデックス不足が判明した場合は
    追加を実装せず人間へ提案として test-results.md に記録する（7.2, 7.3）
  - 完了条件: 全テストグリーン+回帰確認結果を `.kiro/specs/jcx-lineage-lock-2026-27/
    test-results.md` に記録し、外部API応答仕様変更・運用モード切替手順を含む結合試験項目を
    `integration-test-checklist.md` に残す
  - _Requirements: 7.1, 7.2, 7.3_
  - _Depends: 3.1, 3.2, 4.1, 4.2, 5.1, 5.2, 6.1_
