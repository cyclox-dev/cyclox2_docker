# Roadmap

## Overview

AJOCC 2026-27シーズン規則改正（https://www.cyclocross.jp/news/2026/07/20262027amendment.html）への
cyclox2 対応プロジェクト。実力別エリート（ME1〜ME4 = categories.code C1〜C4）と実力別マスターズ
（MM1〜MM3 = CM1〜CM3）の認定カテゴリーを連動させる（対応: ME1⇔MM1※、ME2⇔MM1、ME3⇔MM2、ME4⇔MM3。
※MM1→ME1 は元ME1のみ）。あわせて、二重付与（対応外ペアの同時保有）を仕組みで防止し、既存の不整合
データを是正バッチで修正する。新8区分ポイント表（AJOCC_267）の本番化、残留ライン等のパラメータ変更、
JCXシリーズ戦の系統固定制御も本プロジェクトで対応する。

改修対象は主に cyclox2web（CakePHP 2.x、submodule `cyclox2_svr/cyclox2/`）。
成績閲覧アプリ cyclox2res-sys への影響は各 spec の設計フェーズで確認する。

## Approach Decision

- **Chosen**: 案A「対応ペア両保有モデル」。選手は対応ペア（例: C3 と CM2）の両カテゴリーを
  `category_racers` 上で同時有効保有（`cancel_date=NULL`）する状態を正常とする。昇格・降格・切替は
  両系統を連動更新する。AJOCC 改正文の「次のシーズンでの認定カテゴリーは ME3・MM2 となる」と整合。
- **Why**: 既存の `category_racers` 構造・履歴管理をそのまま使え、改修範囲を局所化できる。
  ME1⇔MM1 の非対称制約も履歴（元ME1判定）で表現可能。
- **Rejected alternatives**: 案B「単一実力レベルモデル」（認定を1つのレベルに正規化し ME/MM は
  読み替え表示）。データは綺麗になるが `category_code` 参照箇所全域とres-sys側に影響が波及し、
  期限（2026-07-31）内の完了リスクが高いため却下。

## Scope

- **In**:
  1. ME⇔MM 連動機構（両保有モデル・リアルタイム昇格連動・対応外ペア付与のバリデーション）
  2. 既存二重付与データの是正バッチ
  3. 新8区分ポイント表（AJOCC_267）の本番化
  4. 残留ライン等パラメータ変更（ME2/ME3=240位、WE1=80位新設、MM2→MM1昇格上限3名、系統横断残留判定）
  5. JCXシリーズ戦の系統固定制御
- **Out**:
  - 2026-27シーズン末（2027-03）の降格処理の実行そのもの（ルール・runbook 整備までが In）
  - res-sys 側の新機能開発（表示互換性の確認・必要最小限の追随のみ）
  - カテゴリー体系そのものの再設計（案B相当）

## Constraints

- **期限**: 2026-07-31 実装完了（2026-27シーズン開幕前）。本日 2026-07-14 起点。
- **技術**: CakePHP 2.x / PHP 7.3 / MySQL 5.7。既存構造（category_racers の apply_date/cancel_date/
  reason_id 方式）を踏襲。TDD（テスト先行）。
- **合意済み方針**（2026-07-14 ユーザー合意、一部 2026-08-15 改訂）:
  - 連動の表現は案A（両保有モデル）
  - ~~二重付与防止は「エラーで弾く」（自動整合はしない）~~
    → **【2026-08-15 改訂】二重付与は「検知して警告するが保存操作は完了させる」（自動整合はしない）。**
    保存時バリデーションによる拒否は行わない。詳細は下記「Requirement 3 方針転換」節
  - 既存データ是正は「直近の出走実態」基準、バッチは任意タイミングで実行可能
  - 5スコープすべて実装対象
- **運用**: main 直接コミット禁止。ブランチ→push→PR。コミットは人間が判断・実行。
  アプリ本体の変更は submodule（cyclox-dev/cyclox2web）側のブランチで行う。

## Boundary Strategy

- **Why this split**: (1)連動機構がドメインの核で、対応表・ペア判定ロジックを他 spec が参照する。
  (2)データ是正はコード改修と独立に任意タイミングで実行するため別 spec。(3)ポイント表本番化は
  既存の point-sim-2025-26 成果（AJOCC_267_TEST）の昇格作業で独立性が高い。(4)残留・昇格枠の
  パラメータとシーズン末ルールは発効時期が異なる（シーズン末）。(5)JCX固定はエントリー制御という
  別レイヤ。
- **Shared seams to watch**:
  - ME⇔MM 対応表の定義は spec 1 が単一の正とし、spec 2/4/5 はそれを参照する（重複定義禁止）
  - `ResultParamCalcComponent` は spec 1（昇格連動）と spec 4（MM2→MM1上限3名）の両方が触る
  - HoldPoint の付与先カテゴリー（spec 1）と系統横断残留判定（spec 4）の整合
  - ~~spec 2 の是正結果が spec 1 のバリデーションを通ること（是正後データが新ルールで合法）~~
    → **【2026-08-15 改訂】spec 1 は保存を拒否しないため、spec 2 の是正完了は spec 1 適用の
    前提条件ではなくなった。両者は独立してリリース可能。** 代わりに spec 2 は「一度きりの
    移行処理」ではなく**シーズン中も繰り返し実行する運用ツール**として位置づけ直す
  - 管理者向けの不整合一覧・レポートは spec 2（catracer-cleanup Requirement 1）が単独で担当し、
    spec 1 は保存時点の個別検知・警告のみを担う（重複実装禁止）

## Schedule (target: 2026-07-31)

- 07/14–07/16: 全 spec の requirements/design/tasks 作成・承認（/kiro-spec-batch → 人間レビュー）
- 07/16–07/23: 実装 Wave 1: me-mm-linkage-2026-27、ajocc-point-267-prod（並行）
- 07/20–07/27: 実装 Wave 2: catracer-cleanup-2026-27、season-rules-2026-27、jcx-lineage-lock-2026-27
- 07/27–07/30: 結合試験（ローカルダンプでの是正バッチ実行検証を含む）・レビュー・PR
- 07/31: バッファ／リリース準備完了

## Specs (dependency order)

- [x] me-mm-linkage-2026-27 -- ME⇔MM対応ペア両保有モデルとリアルタイム昇格連動、対応外ペア付与のバリデーション。Dependencies: none
- [x] ajocc-point-267-prod -- 新8区分ポイント表 AJOCC_267 の本番適用（シミュレーション用フラグの恒久化）。Dependencies: none
- [x] catracer-cleanup-2026-27 -- 既存二重付与（対応外ペア）データの是正バッチ（直近出走実態基準・任意タイミング実行）。Dependencies: me-mm-linkage-2026-27
- [x] season-rules-2026-27 -- 残留ライン変更・WE1残留基準新設・MM2→MM1昇格上限3名・系統横断残留判定のルール整備。Dependencies: me-mm-linkage-2026-27
- [x] jcx-lineage-lock-2026-27 -- JCXシリーズ戦における系統固定のエントリー制御。Dependencies: me-mm-linkage-2026-27
  （制御強度は案B=警告+管理者確認で人間承認済み 2026-07-15。警告と回避誘導は強め。実装可能）

> 上記チェックは「spec（requirements/design/tasks）作成完了」を示す。実装は未着手。

## Cross-Spec Review (2026-07-15)

5 spec 横断の整合レビュー実施済み。致命的な矛盾・重複定義なし。確認済み事項:
CategoryLineageMap/Linker の単一ソース参照（API名まで一致）、ResultParamCalcComponent の
メソッドレベル非衝突（実コード裏取り済み）、reason_id 実値整合、ME1特例の文言一致、
中断復旧した2spec（catracer-cleanup / jcx-lineage-lock）のタスクグラフ健全性（全ACカバー・TDD・非循環）。

フォローアップ（実装時に対応）:
1. [important/解決済み] jcx-lineage-lock の制御強度モード → 2026-07-15 人間承認（案B・警告と回避誘導は強め）。ready_for_implementation=true に更新済み
2. [minor] me-mm-linkage: category_racers 保存経路 13/14 の差分1経路を、保存時バリデーション実装着手前に再grepで特定・記録
3. [minor] ajocc-point-267-prod: 実装着手時に submodule を git fetch 後の最新 origin/main（PR #12 マージ済み）へ更新すること（現ローカルは古い detached HEAD）
4. [minor] Wave1（me-mm-linkage）のフィクスチャ実装完了を確認してから Wave2 の実装に着手（フィクスチャ重複定義防止）

## Requirement 3 方針転換（2026-08-15・有識者レビュー反映）

cyclox2web PR #13（me-mm-linkage-2026-27 実装）への有識者レビューを受け、**「B: カテゴリーの
厳密な管理（重複許すまじ）」の強制を取り下げ、検知・警告方式へ変更**した。**「A: カテゴリー連携
（Elite⇔Masters）」は当初方針どおり継続する。**

**背景**: cyclox2 はカテゴリー付与の厳密性よりシーズン運営のスムーズさを意図的に優先してきた
設計思想を持つ。外部クライアント cyclox2app はカテゴリーの厳密チェックを行わないため、
cyclox2web 側の一元バリデーションで保存を拒否すると、シーズン中に選手データ／リザルトの
アップロードが停止し主催者からの問い合わせが多発する。

**実コードで確認したリスク（2026-08-15 調査）**:
- `ApiController::upload_category_racers()` の `saveMany()`（CakePHP 2.x 既定 atomic=true）は
  1行の失敗でバッチ全体を保存せず HTTP 400。原因行を呼び出し元に返さない
- `execAddResult()` は `reCalcResults()` 失敗をログのみとし API は 200 を返すが、昇格処理ループが
  中断し以降の選手の昇格が無言で不適用。加えて PR #13 で `__applyRankUp2CM()` の戻り値チェックを
  追加したため、従来無害だった失敗が後続全停止のトリガーになる退行が入っていた

**人間承認事項（2026-08-15）**:
1. me-mm-linkage-2026-27 は requirements まで差し戻して再承認（spec.json 更新済み）
2. 同一カテゴリーの重複付与も拒否ではなく警告止まりとする
3. 警告の到達先は cyclox2web 画面（Flash）／ API レスポンスの警告フィールド／
   管理者向け不整合一覧（spec 2 のレポート機能）の3経路

**各 spec への影響**:
| spec | 影響 |
|---|---|
| me-mm-linkage-2026-27 | Req 3 全面改訂、Req 5/6/8/9 の拒否表現を警告へ、Req 10（外部連携の処理継続性）新設。design/tasks/実装（PR #13）が要改訂 |
| catracer-cleanup-2026-27 | 「是正後データがバリデーションを通ること」の前提が不要に。是正完了が spec 1 適用の前提でなくなり**リリース順序の制約が解消**。運用ツールとしての位置づけへ変更 |
| jcx-lineage-lock-2026-27 | 既に案B（警告）採用済みで同方向。design の「拒否する」記述のみ再確認 |
| season-rules-2026-27 | 実質影響なし（降格 SQL は直接 DB 操作でバリデーション非経由と明記済み） |
| ajocc-point-267-prod | 影響なし（PR #14 独立・完了済み） |

**維持される実装資産**: `CategoryLineageMap` / `CategoryLineageLinker`（対応表・連動ロジック）、
`CatLimitShell` の BOTH 対応、`EntryCatLimit::$BOTH`。改訂は `CategoryRacer` の `$validate` 組み込み
撤回と、それに連なる呼び出し元の失敗ハンドリングに限定される見込み。

## スケジュール改訂の要否（2026-08-15 時点）

当初期限 2026-07-31 は経過済み。2026-27 シーズン開幕に向けた新スケジュールの設定が必要。
本方針転換により **spec 2（既存データ是正）が spec 1 の前提でなくなった**ため、
spec 1 の改訂・リリースを先行させ、spec 2 は運用ツールとして継続的に回す構成が取れる。

## Agent Configuration Policy (2026-07-15 合意)

- 同時起動はオーケストレーター（Fable 5 本体）＋サブエージェント1体まで。並列 Wave 廃止・逐次実行
- モデル割当: 調査=Haiku 4.5（Explore）/ 実装・レビュー・デバッグ=Sonnet 5 / 最重要ゲート検証=本体が直接実施
- 中断復旧は SendMessage 再開（新規起動しない）。サブエージェントは要約のみ返却
- sdd_base_template への反映用引き継ぎ資料: .kiro/specs/sdd-agent-tiering-2026-07/handover.md
