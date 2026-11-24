# Requirements Document

## Project Description (Input)

### 背景・目的

Google Analytics 4 (GA4) のデータを Claude Code / Codex から自然言語で取得・分析できる環境を構築する。
Google Analytics の UI を操作するのではなく、Google Analytics Data API を使用してデータを取得する。

最終的には、Claude Code に以下のような自然言語依頼ができる状態を目指す。

- 先月のPVランキングを取得して
- `/race/` 配下のページをPV順に並べて
- `ajocc_ranking` または `point_series` を含むページのPVを集計して
- 前月と比較してPVが増えたページを調べて
- GAデータを取得して結果を分析して

### GA4情報

- 対象GA4 Property ID: `382777249`（API上は `properties/382777249` と指定）

### 使用API

- Google Analytics Data API
  - 主に `properties.runReport`
  - 必要に応じて `properties.runRealtimeReport`、`properties.batchRunReports`
- Google Analytics Admin API は今回不要（GA設定変更ではなく分析データの読み取りが目的）

### 認証方式

- サービスアカウント認証を使用する（OAuthによるユーザー認証は現段階では不要）
- 想定利用元: Claude Code、Codex、ローカルCLI、バッチ、将来的なMCP Server
- いずれも固定された自社GA4プロパティのデータを取得する用途

### 認証の実体（AIからAPIを叩く際のフロー）

Claude Code自身がGA APIに対して直接認証するわけではない。Claude CodeはBashツール等でCLIプロセス（Python）を起動するだけで、実際にGoogleへ認証するのはそのCLIプロセス（`google-analytics-data`ライブラリ内部）である。

```
Claude Code (Bashツールでコマンド実行)
    │  例: ga page-ranking --start ... --end ...
    v
GA CLI プロセス (Python)
    │  google.auth.default() でADCを解決
    v
google-auth ライブラリ
    │  GOOGLE_APPLICATION_CREDENTIALS の JSON鍵を読み込み
    │  秘密鍵でJWTに署名 → Googleのトークンエンドポイントへ交換要求
    v
OAuth2アクセストークン(Bearer token)を取得
    │
    v
Google Analytics Data API (properties.runReport)
```

認証の実体は「サービスアカウントの秘密鍵を使ったJWTベースのOAuth2認証」であり、`google-analytics-data`ライブラリが内部で処理する。CLI実装側では認証情報を明示的に渡さず、`BetaAnalyticsDataClient()`をそのまま呼び出せばよい。`google.auth.default()`はADCの解決順序（①`GOOGLE_APPLICATION_CREDENTIALS`環境変数 → ②`gcloud auth application-default login`のユーザー資格情報 → ③GCE/Cloud Run等のメタデータサーバ）をたどり、今回の構成では①のサービスアカウントJSON鍵に到達する。

実行環境上の注意点:

- `GOOGLE_APPLICATION_CREDENTIALS` はClaude CodeがBashツールを実行するシェルの環境変数として事前に設定されている必要がある（`~/.zshrc`等への`export`、またはCLIラッパー内での明示的な設定）。Claude Codeが自動で鍵ファイルを見つけてくれるわけではない。
- Claude Code（AI）自身が秘密鍵の中身に触れない設計にすることはできるが、これはあくまで運用ルール（鍵ファイルをcat/readしない、ログへ出力しない）による担保であり、技術的な隔離ではない。ClaudeはBashツールでファイルを読める権限を持つため、鍵ファイルを直接読ませない・出力させないというルールをSkillおよびCLAUDE.mdに明記する必要がある。
- 鍵ファイルのパーミッションは`chmod 600`程度に絞り、プロジェクトディレクトリ外（`~/.config/<project>/`等）に置くことで、`git add .`等での誤コミットや`.gitignore`漏れのリスクを下げる。

将来MCP Server化した場合は、認証情報の解決がMCP Server起動時の1回のみになり、Claude CodeはMCPツール呼び出しを行うだけで鍵ファイルのパスを意識しなくなる。今回の第一段階（CLI直接呼び出し）では、Claude Codeの実行シェルに環境変数が設定されている前提が必要な点が、MCP化との主な違いである。

### GA側の権限状況

- 現在のユーザーはGAアカウントの管理者権限を持たないため、自分でサービスアカウントをGA4へ追加できない
- GA4管理者に「サービスアカウントのメールアドレスを Property ID 382777249 の『閲覧者』として追加」を依頼する必要がある
- 可能であればアカウント全体ではなく対象プロパティのみへの権限付与とする（Data APIからのレポート取得のみのため「閲覧者」権限で十分）

### Google Cloud側で必要な設定

1. Google Cloud Projectの作成または既存Projectの使用
2. Google Analytics Data APIの有効化
3. Service Accountの作成
4. Service Accountの認証方法（鍵）の準備
5. GA4管理者によるService AccountのGA4への登録

### GCP権限とGA4権限の関係

GCPのAPIを使う権限と、GA4のデータを見る権限は別々の仕組みである。この2つを混同しないようにする。

- GCPプロジェクトの作成、Data APIの有効化、サービスアカウントの作成は、GCPのIAM（Google Cloud側の権限管理）だけで完結する。GA4への権限を持っていないアカウントでも行える
- 作ったサービスアカウントが実際にGA4のデータを取得できるかどうかは、GA4側のIAM（Googleアナリティクスの管理画面でのユーザー管理）だけで決まる
- 具体的には、GCP側で作ったサービスアカウントの**メールアドレス**を、GA4管理者がGA4プロパティ382777249の「閲覧者」として追加することで、そのサービスアカウントはData API経由でデータを取得できるようになる。逆に言えば、この追加が行われるまでは、サービスアカウントがGCP側でどれだけ正しく設定されていても、GA4のデータには一切アクセスできない
- つまり「サービスアカウントを作る作業（GCP側）」と「そのサービスアカウントにデータを見せてよいと許可する作業（GA4側）」は別の人が行ってよいし、別のタイミングで行ってもよい。サービスアカウントを作る作業自体にGA4の管理権限は不要である

### 認証情報の管理方針（絶対条件）

- Service Accountの秘密鍵をGit Repositoryへ保存してはならない
- 以下には絶対に秘密鍵を書かない: `CLAUDE.md`、`AGENTS.md`、`SKILL.md`、ソースコード、Git Repository、Docker Image
- ローカル開発では例えば `~/.config/<project>/ga-service-account.json` 等に配置する
- 認証には Application Default Credentials を使用する（例: `export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/<project>/ga-service-account.json"`)
- Pythonコード側に認証ファイルのパスを直接記述せず、Application Default Credentialsから取得する
- ログへ秘密鍵を出力しない
- 必要最小限のGA権限（閲覧者）を使用し、原則として対象プロパティのみに権限を付与する

### 設計方針（レイヤー構造）

```
Claude Code / Codex
    |
    v
GA Analysis Skill（Claude Code用） / AGENTS.md（Codex用）
    |
    v
GA CLI / Library（共通、Claude Code固有実装にしない）
    |
    v
Google Analytics Data API
    |
    v
GA4 Property 382777249
```

Claude CodeがGA APIのREST詳細を毎回組み立てる設計にはせず、共通ツール（CLI）を呼び出してGAデータを取得する構成とする。

### 第一段階: CLI実装（MCP Serverは今回作らない）

想定構成例（プロジェクト構成に応じて調整可）:

```
tools/
  ga/
    __init__.py
    client.py
    cli.py
    requirements.txt
```

使用ライブラリ: Google公式Python Client Library `google-analytics-data`

基本用語（GA4 dimension / metric）:

- ページビュー metric: `screenPageViews`
- ページ dimension: `pagePath`
- ページタイトル dimension: `pageTitle`
- 日付 dimension: `date`
- イベント dimension: `eventName`
- イベント数 metric: `eventCount`
- アクティブユーザー metric: `activeUsers`
- セッション metric: `sessions`

最初に提供するCLI機能:

1. **page-ranking**: ページ別PVランキング（`dimension=pagePath`, `metric=screenPageViews`、PV降順）。例: `ga page-ranking --start 2026-08-01 --end 2026-08-09`
2. **path-prefix オプション**: `pagePath` へのFilterで特定パス配下だけを取得可能にする（例: `--path-prefix /race/`）。page-ranking等と組み合わせて使用
3. **event-ranking**: イベント数ランキング（`dimension=eventName`, `metric=eventCount`）
4. **traffic-sources**: 流入元分析（`sessionSource`, `sessionMedium`, `sessions`, `activeUsers` 等）
5. **query**: 汎用クエリコマンド（`--dimension`, `--metric`, `--start`, `--end` を自由指定）。ただし通常の分析ではpage-ranking等の用途別commandを優先する

出力形式:

- Claude Codeから利用しやすくするため、CLIの標準出力はJSONを基本とする
  ```json
  {
    "propertyId": "382777249",
    "startDate": "2026-08-01",
    "endDate": "2026-08-09",
    "rows": [
      { "pagePath": "/", "screenPageViews": 12345 },
      { "pagePath": "/race/foo", "screenPageViews": 5432 }
    ]
  }
  ```
- 人間向け表示が必要な場合、`--format table` などを追加してもよい。デフォルトはJSON

エラー処理:

以下を識別できるようにし、Claude Codeが原因を判断できるよう内容を明示的に出力する。

- `GOOGLE_APPLICATION_CREDENTIALS` 未設定
- Service Account認証失敗
- GA Propertyへの権限不足
- Property ID不正
- Dimension / Metricの互換性エラー
- APIクォータエラー
- 通信エラー

### Skill化（CLIが動作した後）

Skill名例: `ga-analysis`

Skillの役割:

- GA分析要求を検出
- 適切なCLI commandを選択
- GA APIから実データを取得
- データを分析
- GA取得結果とAIによる推論を区別する

Skillに記載する基本ルール（概念）:

- Google Analytics分析では、必ずGAツールからデータを取得すること
- GAの数値を推測してはいけない
- GA4 Property ID: `382777249`
- ページPVには`screenPageViews`を使用する
- ページ単位では`pagePath`を使用する
- GA APIから取得した事実と、その数値から導いた分析・推論を明確に区別する

### CLAUDE.md追記方針

ProjectのCLAUDE.mdには詳細なGA API仕様を書き込まない。以下程度のルールのみを置く。

```
## Google Analytics

Google Analyticsに関する分析では
ga-analysis Skillを使用すること。

GAの数値を推測してはならない。
必ずGoogle Analytics Data APIから実データを取得すること。
```

詳細な操作方法はSkillへ置く。

### 将来的なCodex対応

同じCLIをCodexからも利用できるようにする。

```
Claude Code ----+
                |
Codex ----------+--> GA CLI --> GA Data API
```

Codex側ではAGENTS.md / Skillから同じCLIを利用する。CLI層をClaude Code固有実装にしないこと。

### 将来拡張: MCP（今回のスコープ外）

GA取得を頻繁に利用するようになった場合、CLI/libraryをベースにMCP Server化する。

想定Tools: `ga_get_page_ranking`, `ga_get_event_ranking`, `ga_get_traffic_sources`, `ga_query`

MCP Server内部から既存のGA Client Libraryを呼び出す。CLI実装を捨てず、共通Libraryとして再利用する。今回の段階では実装しない。

### 最終的な構造イメージ

```
CLAUDE.md
    |
    v
ga-analysis Skill
    |
    v
GA CLI / MCP
    |
    v
GA Client Library
    |
    v
Google Analytics Data API
    |
    v
GA4 Property
382777249
```

### 実装優先順位（参考）

1. 現在のRepository構成を確認
2. GA CLIの適切な配置場所を決定
3. `google-analytics-data` dependency追加
4. GA Client実装
5. page-ranking実装
6. JSON出力実装
7. 認証エラー処理
8. path-prefix Filter対応
9. event-ranking実装
10. traffic-sources実装
11. READMEまたは利用方法を記載
12. Claude Code Skill作成
13. CLAUDE.mdにGA Skill利用ルール追加

MCP化はこの段階では行わない。

### 最初の疎通確認

Service AccountがGA4へ登録された後、最初に単純な`runReport`で疎通確認する。

- Property: `properties/382777249`
- Dimension: `pagePath`
- Metric: `screenPageViews`
- Date: `7daysAgo` - `today`

正常にページとPVが取得できれば、認証およびGA API接続は成功と判断する。

### セキュリティ要件（絶対条件）

- Service Account秘密鍵をGit管理しない
- API認証情報をSkillへ記載しない
- CLAUDE.mdへ秘密情報を書かない
- ログへ秘密鍵を出力しない
- 必要最小限のGA権限を使用する
- 原則として対象Propertyのみ閲覧権限を付与する

### 完了条件（第一段階）

以下がすべて満たされたら第一段階完了。

Claude Codeに「2026年8月1日から8月9日までのページ別PVランキングを調べて」と依頼すると、

1. ga-analysis Skillを利用する
2. GA CLIを実行する
3. Property 382777249からデータを取得する
4. PVランキングを返す
5. 実データと分析結果を区別して説明する

という一連の処理が、ユーザーによる追加のCLI操作なしで実行できること。

### 補足（このリポジトリ固有の前提）

- 本機能は cyclox2_docker（サイクルクロス大会管理システム）の既存spec群（AJOCC規則改正対応等）とは独立した新規機能である
- 既存のGA用Google Cloud Project / Service Accountの有無、対象GA4プロパティのデータストリーム構成などは未確認であり、実装着手前に運用者（人間）が確認・準備する
- 管理用issue: [#41](https://github.com/cyclox-dev/cyclox2_docker/issues/41)
- 親issue: [#37](https://github.com/cyclox-dev/cyclox2_docker/issues/37)「AJOCCシーズン実績レポートの自動作成」。その第1タスク「GA4へのエージェントからの自動接続」が本機能に相当する
- 関連issue: [#36](https://github.com/cyclox-dev/cyclox2_docker/issues/36)「Xserver側サイトへGA4-tagを導入する」。別ドメインへの新規計測導入であり、本機能とは独立して進む

### 先行タスクからの引き継ぎ事項

2025-26シーズンレポート作成タスク（`ajocc-report-2025-26`）で判明した技術情報が
`.kiro/specs/ajocc-report-2025-26/ga4-automation-handover.md` に記録されている。本要件に影響する主な内容は次のとおり。

- **「その他」バケット問題**: リザルト（`/race/<id>`）・ランキング（`/ajocc_ranking/<...>`、`/point_series/<id>`）・選手検索・選手データの各カテゴリが、現行のGA4プロパティ設定ではコンテンツグループとして定義されておらず `(other)` に一括計上されている。解決策は「GA4管理画面でコンテンツグループを設定する」か「Data APIでパスのパターンマッチにより集計する」かの2つだが、**GA4の管理権限がないため前者は選べず、後者が唯一の実現手段になる**
- **ランキングは2つのURLパターンで1カテゴリ**: `/ajocc_ranking/` と `/point_series/` の両方に一致するページをまとめて1つの合計として扱う必要がある。単一の前方一致では表現できない
- **選手検索・選手データのURLパターンは未確認**: 別途調査が必要。本要件はパターンを指定できる汎用的な仕組みを提供するところまでを担い、個々のパターンの確定は利用時に行う
- **データ保有期間の制約**: 2025-26シーズン分は本来の2025/4/1〜2026/3/31に対し、2025/9/1〜2026/3/31の7ヶ月分しか取得できなかった。原因は未特定だがGA4のデータ保有期間設定が疑われる

## Introduction

本機能は、Claude CodeやCodexなどのAIエージェントに「GA4のデータを見て」と自然な言葉で頼めるようにする、最初の段階の仕組みである。対象はGoogle Analytics 4（GA4、Property ID: 382777249）である。GA4の画面を人が操作するのではなく、サービスアカウントという仕組みを使ってGoogle Analytics Data APIから直接データを取得する。

AIエージェントは、GA APIのリクエストを毎回自分で組み立てる必要はない。代わりに「GA CLI」という共通のコマンドラインツールを呼び出すだけでデータを取得できる。CLIが動くようになったら、Claude Code向けに「ga-analysisスキル」を用意する。このスキルが、自然な言葉での分析依頼を受け取り、適切なCLIコマンドを実行し、結果を返すところまでを仲介する。CLI自体はClaude Code専用には作らない。Codexなど他のAIエージェントからも、同じ方法でそのまま使えるようにする。

MCP Serverを作ることは、今回の範囲には含めない。ただし、今回作るCLIと共通ライブラリは、将来MCP化するときにそのまま土台として使える形にしておく。

この機能の主な使われ方は、AIエージェント（Claude Code）が1つの会話の中で、Cyclox2のローカルDBへの問い合わせとGA4データの取得を同時に行い、両方の結果を組み合わせて分析することである。決まった時刻に自動実行される恒久的なバッチ処理ではなく、AIエージェントがその都度必要に応じて実行する使い方を前提とする。この前提があるため、認証はサービスアカウントとローカルの鍵を使うシンプルな方法で十分であり、恒久バッチ向けの「鍵を使わない仕組み」やクラウド上での実行は今は必要ない。また、出力する結果は他のデータと組み合わせやすい、構造化されたデータにする必要がある。

## Boundary Context

- **In scope**:
  - GA4のProperty 382777249に対して、サービスアカウントで認証し、Google Analytics Data API（`runReport`に相当する機能）でデータを取得すること
  - 次の5つの取得機能: ページ別PVランキング（page-ranking）、パスによる絞り込みとカテゴリ合計の取得（path-prefix / 複数パターン / 正規表現）、イベント数ランキング（event-ranking）、流入元の分析（traffic-sources）、自由に条件を指定できる汎用クエリ（query）
  - 結果はJSON形式で返すことを基本とし、人が読みやすい表形式で出力するオプションも用意すること
  - 結果が行数の上限で打ち切られた場合や、指定期間のデータが取得できなかった場合に、利用者がそれと気づけるようにすること
  - 認証エラー・権限不足・Property IDの誤り・DimensionとMetricの組み合わせ違反・クォータ超過・通信エラーなど、原因ごとに区別できるエラー表示
  - サービスアカウントの秘密鍵をGitに含めない・ドキュメントに書かない・必要最小限の権限だけを使うという運用
  - Claude Code向けの「ga-analysisスキル」が自然な言葉での依頼を仲介し、実際のデータと、そこからの分析・推測をはっきり分けて示すこと
  - Codexなど、Claude Code以外からも同じCLIをそのまま使えるようにすること
  - GA CLIの事前準備・使い方・出力形式をまとめた利用方法のドキュメントを用意すること
- **Out of scope**:
  - MCP Serverを作ること（CLIと共通ライブラリを整備するところまでが今回の範囲で、MCP化自体は将来の対応とする）
  - Google Analytics Admin APIに相当する操作（GA4のプロパティ設定やデータストリームの設定などを変更すること）
  - OAuthを使ったユーザー認証の仕組みを作ること
  - 対象サイトにGoogle Analyticsの計測タグ（gtag/GTM）を新しく入れる作業
  - Google Cloud Projectの作成、APIの有効化、サービスアカウントの作成、GA4管理者による閲覧者登録といった、人が行うセットアップ作業そのものを自動化すること（IaC化など）
  - `runRealtimeReport`や`batchRunReports`を使った機能（必要になったときの拡張候補とし、今回は必須にしない）
- **Adjacent expectations**:
  - 対象のGA4プロパティ（382777249）は `data.cyclocross.jp` を計測しており、すでに計測タグが入ってデータがたまっていることを前提とする。一方、AJOCC本体ページ（Xserver管理）は現時点で計測タグが入っておらず、本機能で取得できる数値には含まれない（別issue #36 で対応中）。本機能はこの計測範囲を広げるものではない
  - 対象のGA4プロパティでは、リザルト・ランキング・選手検索・選手データの各カテゴリがコンテンツグループとして定義されておらず、`(other)` に一括計上されている。本機能のパスによる絞り込みと合計の機能（Requirement 4）は、GA4管理画面の設定を変えずにカテゴリ別の集計を可能にする手段として位置づける。GA4管理画面側の設定変更は本機能では行わない
  - GA4のデータ保有期間の設定によっては、指定した期間の全部または一部のデータが取得できない場合がある。本機能はこの保有期間の設定を変更しない。取得できなかった場合に利用者がそれと気づけるようにすることまでが本機能の責任範囲である（Requirement 2）
  - 本機能のパスによる絞り込みは、クエリ文字列（`?` 以降）を除いたパス部分で判定する。URLパターンが未確認のカテゴリ（選手検索・選手データ）が、パス部分では区別できずクエリ文字列でしか分けられない構造だった場合、本機能の絞り込みではそのカテゴリを分離できない。その場合は別途の対応が必要になる
  - GA4管理者が、サービスアカウントにプロパティの閲覧権限をすでに付与していることを前提とする。この権限付与の作業自体は、本機能が代わりに行うものではない
  - Google Cloud Projectの作成、APIの有効化、サービスアカウントの作成は、本機能を動かすために必要な準備である。ただし、これらの作業を行うのは運用者（人間）であり、本機能はその結果（すでに作られたサービスアカウントと鍵）を使う側にすぎない
  - 本機能は、AIエージェントがCyclox2のローカルDBへの問い合わせ（このspecの対象外）と組み合わせて使うことを前提とする。ただし、複数のデータを組み合わせて分析する処理自体はAIエージェント側が行うものであり、GA CLIやga-analysisスキルがローカルDBに直接アクセスしたり、DBとのデータ結合を行ったりすることはない

## Requirements

### Requirement 1: サービスアカウント認証とGA4プロパティ疎通

**Objective:** GA CLIを使う人（開発者やAIエージェント）が、GA4の画面を操作しなくてもデータを取れるように、サービスアカウントでGA4のProperty 382777249に接続できるようにする。

#### Acceptance Criteria
1. When GA CLIがGA4データ取得のコマンドを実行するとき, GA CLI shall サービスアカウントの認証情報を使ってGoogle Analytics Data APIに接続する
2. If サービスアカウントの認証情報が設定されていないままGA CLIを実行した場合, GA CLI shall 「認証情報が設定されていません」とわかるエラーメッセージを出して終了する
3. If サービスアカウントの認証情報が正しくない、または認証に失敗した場合, GA CLI shall 「認証に失敗しました」とわかるエラーメッセージを出して終了する
4. If 認証には成功したが、対象のGA4プロパティ（382777249）を見る権限がない場合, GA CLI shall 「権限が足りません」とわかるエラーメッセージを出して終了する
5. The GA CLI shall 何も指定しなければGA4プロパティ382777249を対象にする
6. Where 対象のGA4プロパティIDを明示的に指定したとき, GA CLI shall 既定値の代わりに指定されたプロパティIDを使う

### Requirement 2: 日付範囲の検証とデータ取得範囲の明示

**Objective:** 日付の範囲を指定するすべてのコマンドで、入力チェックのルールを揃えたい。あわせて、依頼した期間のうち実際にどこまでデータが取れたのかを利用者に伝えたい。日付の指定間違いや、GA4のデータ保有期間の制約による部分的なデータ欠落に気づかないまま、誤った分析をすることを防ぐためである。

#### Acceptance Criteria
1. If 開始日または終了日が必要なコマンドで、どちらかが指定されなかった場合, GA CLI shall 「日付の指定が足りません」とわかるエラーメッセージを出す
2. If 指定した開始日が終了日より後になっている場合, GA CLI shall 「日付の範囲が正しくありません」とわかるエラーメッセージを出す
3. The GA CLI shall 日付として `YYYY-MM-DD` 形式と、GA4が解釈する相対日付表記（`7daysAgo`・`yesterday`・`today` など）の両方を受け付ける
4. If 指定した日付がどちらの書式にも当てはまらない場合, GA CLI shall 「日付の書式が正しくありません」とわかるエラーメッセージを出す
5. The GA CLI shall 結果に、依頼された開始日と終了日をそのまま含める。相対日付表記で指定された場合は、解決したあとの具体的な日付もあわせて含める
6. The GA CLI shall 相対日付表記の解決と日付の判定に、対象GA4プロパティに設定されたタイムゾーンを用いる
7. The GA CLI shall 結果に、取得できたデータの実際の期間（結果に含まれるデータのうち最も古い日と最も新しい日）を含める。パスによる絞り込みを指定した場合は、絞り込んだあとのデータについての期間とする。データが0件で期間を特定できない場合は、その項目が空であることを明示する
8. The GA CLI shall 「依頼された期間の古い側にデータが存在するか」の判定を、パスによる絞り込みをしていない状態のデータに基づいて行う。特定のページのアクセスが少ないだけの状態を、期間全体のデータ欠落と取り違えないためである
9. If 依頼された期間の古い側にデータが存在しない場合, GA CLI shall その旨を警告として示し、GA4のデータ保有期間の設定が原因である可能性に言及する。この警告はパスによる絞り込みの有無にかかわらず示す
10. If 結果が0件で、かつパスによる絞り込みを指定していない場合, GA CLI shall エラーにはせず0件を返したうえで、指定した期間にデータが存在しないことを警告として示し、GA4のデータ保有期間の設定が原因である可能性に言及する

### Requirement 3: ページ別PVランキング取得（page-ranking）

**Objective:** 特定の期間について、ページ別のPVランキングを取得したい。どの期間にどのページがよく見られているかを把握するためである。

#### Acceptance Criteria
1. When 開始日と終了日を指定してページ別PVランキングの取得を求めたとき, GA CLI shall その期間のページ（pagePath）ごとのページビュー数（screenPageViews）を、多い順に並べて返す
2. The GA CLI shall ページ別PVランキングの結果に、対象のプロパティID・開始日・終了日を含める
3. Where ページ別PVランキングでパスによる絞り込みを指定したとき, GA CLI shall Requirement 4の絞り込みと合計の規則を適用する

### Requirement 4: パスによる絞り込みとカテゴリ合計の取得

**Objective:** 「/race/配下だけ」のように特定のパスに絞ってPVを見たい。さらに「`/ajocc_ranking/` または `/point_series/` に一致するページ全体の合計」のように、複数のURLパターンを1つのカテゴリとしてまとめた合計値も取得したい。GA4管理画面のコンテンツグループ設定に頼らずに、サイトのカテゴリ別のPVを集計できるようにするためである。

#### Acceptance Criteria
1. The GA CLI shall パスによる絞り込みを、ページ別PVランキング（Requirement 3）と汎用クエリ（Requirement 7）で利用できるようにする。イベント数ランキング（Requirement 5）と流入元分析（Requirement 6）では利用できなくてよい
2. The GA CLI shall 絞り込みの判定対象を、クエリ文字列（`?` 以降）を除いたページのパス部分とする
3. Where パスの先頭部分（プレフィックス）を1つまたは複数指定したとき, GA CLI shall そのいずれか1つ以上で始まるページを結果に含める
4. Where 正規表現によるパス指定をしたとき, GA CLI shall その正規表現に一致するページを結果に含める
5. If プレフィックス指定と正規表現指定が同時に指定された場合, GA CLI shall 「パスの指定方法が競合しています」とわかるエラーメッセージを出す
6. When パスの指定をせずに取得するとき, GA CLI shall 絞り込みをせず、すべてのページを対象にする
7. If 指定したパスに一致するページが1つもない場合, GA CLI shall エラーにはせず0件を返したうえで、絞り込み条件に一致するページがなかったことを示す。このとき、0件になった原因をデータ保有期間に帰属させない（期間そのもののデータ有無に関する警告はRequirement 2で別に扱う）
8. The GA CLI shall 絞り込んだ結果に、一致したページ全体の指標の合計値を含める。この合計値は、返す行数の上限によって結果が打ち切られた場合でも、一致した全ページ分を反映した値とする
9. The GA CLI shall 合計値として、返した行の数値を足し合わせた値ではなく、GA4が対象範囲全体に対して算出した集計値を用いる。アクティブユーザー数（activeUsers）のように重複を含み単純加算できない指標でも正しい値になるようにするためである
10. If 指定した正規表現の書式が正しくない場合, GA CLI shall 「パスの指定が正しくありません」とわかるエラーメッセージを出す

### Requirement 5: イベント数ランキング取得（event-ranking）

**Objective:** 特定の期間について、イベント数のランキングを取得したい。よく発生しているイベントの傾向を把握するためである。

#### Acceptance Criteria
1. When 開始日と終了日を指定してイベント数ランキングの取得を求めたとき, GA CLI shall その期間のイベント名（eventName）ごとのイベント数（eventCount）を、多い順に並べて返す
2. The GA CLI shall イベント数ランキングの結果に、対象のプロパティID・開始日・終了日を含める

### Requirement 6: 流入元分析取得（traffic-sources）

**Objective:** 特定の期間について、流入元ごとのセッション数・アクティブユーザー数を取得したい。どの流入経路からのアクセスが多いかを把握するためである。

#### Acceptance Criteria
1. When 開始日と終了日を指定して流入元の分析を求めたとき, GA CLI shall その期間のセッション参照元（sessionSource）とメディア（sessionMedium）の組み合わせごとに、セッション数（sessions）とアクティブユーザー数（activeUsers）を返す
2. The GA CLI shall 流入元分析の結果に、対象のプロパティID・開始日・終了日を含める

### Requirement 7: 汎用クエリ機能（query）

**Objective:** ディメンションと指標を自由に指定して、GA4のデータを取得したい。用途別のコマンドでは対応できない分析にも対応するためである。

#### Acceptance Criteria
1. When ディメンション・指標・開始日・終了日を指定して汎用クエリを求めたとき, GA CLI shall 指定されたディメンションと指標の組み合わせでGA4のデータを取得して返す
2. If ディメンション・指標・開始日・終了日のいずれかを指定しなかった場合, GA CLI shall 「必要な指定が足りません」とわかるエラーメッセージを出す
3. The GA CLI shall 汎用クエリの結果にも、ほかのコマンドと同じ出力形式のルール（Requirement 8）を適用する
4. Where 汎用クエリでパスによる絞り込みを指定したとき, GA CLI shall ページ別PVランキングと同じ絞り込みと合計の規則（Requirement 4）を適用する

### Requirement 8: 出力形式

**Objective:** GA CLIの出力は、何もオプションを指定しなければ機械が読み取りやすい形式にしたい。取得結果をそのまま解析や加工に使えるようにするためである。

#### Acceptance Criteria
1. The GA CLI shall オプションを指定しないときの出力形式としてJSON形式を使う
2. The GA CLI shall JSON形式の出力に、次をすべて含める。対象のプロパティID／依頼された開始日と終了日／実際にデータが存在した期間／結果の一覧（ディメンションの値と指標の値の組み合わせ）／絞り込みを行った場合はその合計値／警告があればその内容／結果が打ち切られた場合はその事実
3. Where 人向けの表形式で出力するオプションを指定したとき, GA CLI shall 取得結果を表の形に整えて画面に出力する。このとき合計値・警告・打ち切りの有無もあわせて示し、JSON形式より情報が欠けないようにする
4. If 取得できる行数の上限に達して結果の一部しか返せなかった場合, GA CLI shall 結果が途中で打ち切られたことを利用者が判別できる情報を出力に含める。打ち切りを黙って隠さない

### Requirement 9: エラー種別の識別（認証以外）

**Objective:** 認証以外のエラーについても、種類ごとに区別できる形で出力したい。AIエージェントが原因に応じた対応を自分で判断できるようにするためである。

#### Acceptance Criteria
1. If 指定したProperty IDが正しくない場合, GA CLI shall 「Property IDが正しくありません」とわかるエラーメッセージを出す
2. If 指定したディメンションと指標の組み合わせがGA4上で使えない場合, GA CLI shall 「その組み合わせは使えません」とわかるエラーメッセージを出す
3. If Google Analytics Data APIからクォータ超過の応答が返ってきた場合, GA CLI shall 「クォータを超えました」とわかるエラーメッセージを出す
4. If Google Analytics Data APIとの通信中に接続エラーが起きた場合, GA CLI shall 「通信エラーが発生しました」とわかるエラーメッセージを出す
5. The GA CLI shall 出力するすべてのエラーメッセージに、エラーの種類がわかる情報を含める
6. If 上のどれにも当てはまらないエラーが起きた場合, GA CLI shall 「想定外のエラーが発生しました」というメッセージと元のエラー内容を出す。エラーを黙って握りつぶさない
7. The GA CLI shall 異常終了したことを、成功時と機械的に区別できる形で返す。具体的には、0以外の終了コードを返し、あわせてエラーの種類を識別できる符号を出力に含める。AIエージェントが正常な0件の結果とエラーを取り違えないようにするためである

### Requirement 10: 秘密情報の管理と最小権限

**Objective:** サービスアカウントの秘密鍵が、コミット・記載・出力のどの経路からも漏れないようにしたい。GA4データへの不正アクセスを防ぐためである。

#### Acceptance Criteria
1. The GA4連携の仕組み全体（CLI・スキル・設定・ドキュメント） shall サービスアカウントの秘密鍵の値をGit管理下のファイルに含めない
2. The GA4連携の仕組み全体 shall 秘密鍵の値をCLAUDE.md・AGENTS.md・スキル定義ファイルに書かない
3. The GA CLI shall 認証情報の参照先をソースコードに直接埋め込まず、実行時に外部（環境変数など）から受け取る
4. The GA CLI shall 認証情報の値を標準出力・ログ・エラーメッセージに出さない
5. The GA4連携の仕組み全体 shall 対象のGA4プロパティに対して閲覧権限だけを求め、書き込みや管理の権限は求めない
6. The GA4連携の仕組み全体 shall AIエージェントが秘密鍵ファイルの中身を読み出したり、会話や出力へ書き出したりしないというルールを、スキル定義とエージェント向けルール（CLAUDE.md / AGENTS.md）に明記する。AIエージェントは技術的にはファイルを読めてしまうため、運用ルールとして明示する必要があるためである
7. The GA4連携の仕組み全体 shall 秘密鍵ファイルの置き場所をリポジトリの外とし、ファイルの読み取り権限を必要最小限に絞ることを、利用方法のドキュメントで指示する
8. If 認証情報の参照先がGit管理下のディレクトリの配下を指している場合, GA CLI shall 秘密鍵が誤ってGitへ追加されるおそれがある旨を警告する。運用者の配置ミスを実際に検知できるようにするためである

### Requirement 11: 読み取り専用操作の保証

**Objective:** 本機能がGA4の設定やデータを一切変更しないようにしたい。分析用のツールがGA4の運用に影響を与えるリスクをなくすためである。

#### Acceptance Criteria
1. The GA4連携の仕組み全体 shall Google Analytics Admin APIに相当する設定変更の操作を提供しない
2. The GA4連携の仕組み全体 shall GA4のデータや設定を変更する操作を一切行わない

### Requirement 12: Claude Code向けga-analysisスキル

**Objective:** GA4分析の依頼を、自然な言葉のままga-analysisスキルに処理してほしい。CLIのコマンドを自分で組み立てなくても、GA4データの分析を頼めるようにするためである。

#### Acceptance Criteria
1. When ユーザーがGA4に関する分析を自然な言葉で依頼したとき, ga-analysisスキル shall その依頼に合ったGA CLIコマンドを選んで実行する
2. The ga-analysisスキル shall GA4に関する数値を、GA CLIの実行結果からだけ取得し、推測で作り出さない
3. The ga-analysisスキル shall 回答の中で、GA CLIから得た事実の値と、そこから導いた分析・推測をはっきり分けて示す
4. The ga-analysisスキル shall 対象のGA4 Property ID（382777249）を最初から決まった値として扱い、ユーザーに毎回確認しない
5. The GA4連携の仕組み全体 shall 「GA4に関する分析ではga-analysisスキルを使う」「GA4の数値を推測してはならない」という2点を、エージェント向けの共通ルール（CLAUDE.md / AGENTS.md）に記載する。GA APIの詳細な操作方法はそこには書かず、スキル側に置く
6. When 1回のCLI実行では答えられない依頼（前の月との比較など）を受けたとき, ga-analysisスキル shall 必要な回数だけGA CLIを実行し、その結果を突き合わせて回答する
7. The ga-analysisスキル shall 依頼から回答までを、ユーザーによる追加のCLI操作なしで完了する

### Requirement 13: Codex等の他クライアントからの再利用性

**Objective:** Codexからも、Claude Codeと同じGA CLIを使いたい。Claude Code以外の環境でも、同じ方法でGA4データを取得できるようにするためである。

#### Acceptance Criteria
1. The GA CLI shall 特定のAIエージェント（Claude Code）に依存せず、単独のコマンドラインツールとして動く
2. Where Codexから利用する場合, GA CLI shall Claude Codeから使うときと同じコマンド体系・出力形式で動く

### Requirement 14: 利用方法のドキュメント化

**Objective:** GA CLIを初めて使う人が、必要な準備と使い方をたどれるようにしたい。認証情報の設定など、事前の準備なしでは動かない仕組みであるためである。

#### Acceptance Criteria
1. The GA4連携の仕組み全体 shall GA CLIの利用方法をドキュメントとして提供する。内容には、必要な事前準備（Google Cloud側の設定、GA4管理者による権限付与、認証情報の置き場所と環境変数の設定）、各コマンドの使い方、出力形式を含める
2. The 利用方法のドキュメント shall 秘密鍵の値そのものを記載しない
