# CLAUDE.md

このファイルはClaude Code (claude.ai/code) がこのリポジトリで作業する際のガイダンスを提供します。

## 基本方針

### ドキュメント方針

記載後に以下の観点で見直して品質を保つ

- **矛盾排除**: 文書内で矛盾する記載がないか
- **曖昧性解消**: 実装やアーキテクチャのブレが生じそうな曖昧さがないか
- **構成最適化**: 人が理解しやすい見出しの構成になっているか
- **重複排除**: 記載の重複がないか

### 実装方針

- **最新版パッケージ**: パッケージを導入するときはWebで最新版を探して導入する
- **実装前合意**: 対話ではすぐに実装しない。実装方針を提示して合意してから進める
- **アーキテクチャ遵守**: DESIGN.mdの設計に従い、変更時は設計書も更新する
- **セキュリティ考慮**: AWS IAM最小権限、シークレット管理を徹底する

## プロジェクト構成

モノレポ構成で複数の技術領域を統合管理：

```
.
├── .devcontainer/     # 開発コンテナ設定
├── apps/              # アプリケーション（Slack Bot、Issue管理等）
├── terraform/         # インフラストラクチャ定義（AWS Bedrock、Lambda等）
├── aqua.yaml          # CLIツールのバージョン管理設定
├── compose.yaml       # Docker Compose設定
├── CLAUDE.md          # 開発ガイドライン（このファイル）
├── DESIGN.md          # システム全体のアーキテクチャ設計書
└── INSTRUCTIONS.md    # 作業指示・実装タスク
```

## 開発環境

### パッケージ管理

#### Aqua

**Aquaパッケージマネージャー**によるCLIツールのバージョン管理

```bash
aqua install      # aqua.yamlで定義されたツールをインストール
aqua list         # インストール済みツール一覧
aqua which <tool> # ツールのパスを表示
```

### 開発コンテナ

**VS Code Dev Container**による統一開発環境

```bash
# VS Code/Cursorでのコンテナ操作
Ctrl+Shift+P → "Dev Containers: Reopen in Container"     # コンテナで開く
Ctrl+Shift+P → "Dev Containers: Rebuild Container"       # コンテナ再構築
Ctrl+Shift+P → "Dev Containers: Reopen Locally"         # ローカルで開く
```

## AWS環境

### 基本方針

- **Terraformで構築する**: AWSリソースの作成・管理はTerraformを使用してInfrastructure as Codeで実施
- **Lambdaはlambrollでデプロイする**: Lambda関数のデプロイ・管理はlambrollを使用して実施
- **Secrets Managerはデフォルトでdummyという文字列を格納し、手動で値を書き換える**: セキュリティ上、初期値はプレースホルダーとして設定
- **開発コンテナ内では認証設定済み**: 開発コンテナ内ではAWS認証が構成済みのため、AWS CLIやTerraformの認証設定は不要

### 命名規則

#### リソース命名パターン

**組み合わせリソース**: 他のリソースと組み合わせて使用するもの

- 形式: `{env}-{リソース名}-{役割}`
- 対象: VPC、IAM Role/Policy、セキュリティグループ、サブネット等
- 例: `dev-vpc-main`、`dev-role-lambda_execution`、`dev-policy-lambda_execution`、`dev-sg-web_server`

**単独リソース**: 単独で動作するもの

- 形式: `{env}-{役割}`
- 対象: ECS、Lambda、RDS、S3バケット等
- 例: `dev-api_server`、`dev-batch_processor`
- ただしS3はハイフンしか利用できないためすべてハイフン区切りとする

#### 命名規則詳細

- **環境**: `dev`、`stg`、`prd`
- **役割の複数単語**: アンダースコア区切り（例: `web_server`、`data_processor`）
- **英小文字**: 全て小文字で統一
- **略語**: 一般的な略語を使用（`sg` = Security Group、`rds` = RDS等）

### 設計指針

**AWS Well-Architectedフレームワーク**に従って設計・実装を行う。特にセキュリティは重要なため以下を遵守：

- **最小権限の原則**: IAMロールは必要最小限の権限のみ付与
- **シークレット管理**: Secrets Managerを使用してAPI Token・パスワード等を管理
- **暗号化**: S3ステートファイル、Knowledge Base等の保存時暗号化を有効化
- **VPC内配置**: Lambda関数は可能な限りVPC内に配置してネットワーク分離

## Terraform開発

### ディレクトリ構成

```
terraform/
├── main.tf         # Providerの設定とバージョン制約
└── backend.tf      # S3バックエンド設定（ネイティブステートロック）
```

### 初期構築

新しいTerraformプロジェクトを作成する際の初期セットアップ手順：

```bash
# 1. Terraformディレクトリの作成
mkdir -p terraform
cd terraform

# 2. main.tfの作成
# 以下を含むmain.tfを作成：
# - terraform {} ブロック（required_version）
# - required_providers {} ブロック（aws provider v5.0+）
# - provider "aws" {} ブロック（リージョン設定）

# 3. backend.tfの作成
# S3バックエンド設定を含むbackend.tfを作成：
# - backend "s3" {} ブロック
# - バケット: 384081048358-tfstate-2
# - リージョン: ap-northeast-1
# - use_lockfile = true（ネイティブステートロック）

# 4. Terraformの初期化
terraform init      # バックエンド設定とプロバイダーのダウンロード

# 5. 設定の検証
terraform validate  # 構文チェック
terraform fmt      # フォーマット適用
```

この初期構築完了後、DESIGN.mdのシステム概要図に従ってAWSリソースの定義を開始する。

### コマンド

```bash
cd terraform
terraform init      # Terraformの初期化
terraform plan      # インフラ変更の計画
terraform apply     # インフラ変更の適用
```

### 開発ガイドライン

- **MCPサーバーの活用**: 実装前に必ずMCP（Model Context Protocol）サーバーを使用してTerraformの最新仕様と推奨実装を確認する
- **フォーマット**: 実装後に`terraform fmt`を実行してtf/hclファイルを整形する
- **バリデーション**: 実装後に`terraform validate`を実行して構文チェックを行う
- **コード品質**: 実装後に`tflint`を実行して問題を特定・解決する
- **セキュリティチェック**: 実装後に`trivy config .`を実行してセキュリティ脆弱性をスキャンする
- **バージョン**: Terraform v1.12.2とAWS Provider v5.0+

### バックエンド設定

- **ステート保存**: S3バケット`384081048358-tfstate-2`
- **ステートロック**: S3ネイティブロック（DynamoDB不要）
- **暗号化**: ステートファイルの暗号化を有効
- **リージョン**: ap-northeast-1

## Python開発

### アプリケーション構造

各アプリケーションはDESIGN.mdのアプリケーション一覧で定義された仕様に従って実装する：

```
apps/<application_name>/
├── README.md                 # アプリケーション説明
├── DESIGN.md                 # 設計書（詳細なアーキテクチャ）
├── pyproject.toml           # プロジェクト設定
├── uv.lock                  # 依存関係ロックファイル
├── src/
│   └── main.py              # エントリーポイント（DESIGN.mdの入出力仕様に準拠）
├── lambroll/                # Lambdaデプロイ設定
│   └── function.json        # Lambda関数設定（DESIGN.mdのデプロイ先に対応）
├── tests/                   # ユニットテスト（クラス単位）
│   ├── conftest.py          # pytest設定・フィクスチャ
│   ├── test_*.py           # 各srcファイルに対応
│   └── <ディレクトリ>/       # srcディレクトリ構造と対応
│       └── test_*.py
└── tests-it/               # 結合テスト（シナリオ単位）
    ├── conftest.py          # 結合テスト用設定
    └── test_*_scenario.py   # 業務シナリオのテスト
```

### 初期構築

新しいPythonアプリケーションを作成する際の初期セットアップ手順：

```bash
# 1. アプリケーションディレクトリの作成
mkdir -p apps/<application_name>
cd apps/<application_name>

# 2. pyproject.tomlの配置
# DESIGN.mdの仕様に基づいて以下を含むpyproject.tomlを作成：
# - プロジェクト名・説明・バージョン
# - Python要求バージョン
# - 本番依存関係（boto3、injector等）
# - 開発依存関係（pytest、ruff、mypy等）
# - pytestの設定（pythonpath = ["src"]）

# 3. 仮想環境の作成と有効化
uv venv                    # 仮想環境作成
source .venv/bin/activate  # 仮想環境有効化（以降の作業はこの環境で実施）

# 4. 依存関係のインストール
uv sync                    # pyproject.tomlに基づく依存関係インストール

# 5. ディレクトリ構造の作成
mkdir -p src tests tests-it lambroll
touch src/main.py tests/conftest.py tests-it/conftest.py

# 6. Lambdaデプロイ設定の作成（Lambdaアプリの場合）
# lambroll/function.jsonをDESIGN.mdのデプロイ先仕様に合わせて作成
```

この初期構築完了後、DESIGN.mdの入出力仕様に従ってsrc/main.pyの実装を開始する。

### 実装指針

- **入出力仕様**: DESIGN.mdのアプリケーション一覧の入力・出力セクションに準拠
- **デプロイ設定**: DESIGN.mdのデプロイ先情報をlambroll/function.jsonに反映
- **テスト設計**: DESIGN.mdの処理フローを基に結合テストシナリオを作成

### 環境セットアップ

```bash
cd apps/<アプリ名>
uv venv                    # 仮想環境作成
source .venv/bin/activate  # 仮想環境有効化
uv sync                    # 依存関係インストール
```

### コマンド

```bash
# コード品質
uv run ruff format         # コード自動フォーマット
uv run ruff check          # リント実行
uv run ruff check --fix    # リント自動修正
uv run mypy src           # 型チェック

# テスト
uv run pytest            # ユニットテスト実行
uv run pytest -v         # 詳細出力
uv run pytest --cov=src  # カバレッジ付き実行
uv run pytest tests-it/  # 結合テスト実行

# 依存関係管理
uv add <パッケージ名>      # 本番依存関係追加
uv add --dev <パッケージ名> # 開発依存関係追加
uv remove <パッケージ名>   # パッケージ削除

# デプロイ（Lambdaアプリの場合）
lambroll deploy           # Lambda関数をデプロイ
lambroll deploy --dry-run # デプロイ内容の確認
lambroll rollback         # 前のバージョンにロールバック
lambroll delete           # Lambda関数を削除
lambroll delete --dry-run # 削除内容の確認
lambroll logs             # 最新のログを表示
lambroll logs --follow    # ログをリアルタイム監視
```

### 技術スタック

Python開発の標準ツール：

- **uv**: パッケージ管理
- **ruff**: フォーマット・リント
- **mypy**: 型チェック
- **pytest**: テスト
- **lambroll**: Lambdaデプロイ

### 実装ガイドライン

#### コード構成・可読性

- **1ファイル1クラス**: ファイルごとに一つのクラスを定義し、責務を明確化
- **クラス責務の明示**: ファイルの先頭にクラスの責務をコメントで記載
- **単一責任の原則**: 同じクラスに複数の責務がある場合はクラスを分割
- **メソッドの説明**: 各メソッドには処理内容を説明する日本語の一行コメントを付与
- **処理目的の明示**: 複雑あるいは直感的に理解しにくい処理では目的や背景をコメントで記載

#### コード品質・保守性

- **型ヒント必須**: Python型ヒントを付与して型安全性を確保
- **ruffフォーマット**: `uv run ruff format`による自動フォーマット適用
- **ruffリント**: `uv run ruff check`によるリント実行
- **型チェック**: `uv run mypy src`による静的型チェック実行

### テスト方針

#### テスト実装方針

- **1テストメソッド1アサーション**: 単一の観点のみをテストし、失敗原因を明確化
- **Given-When-Then構造**: テストケースを3段階で構造化（準備・実行・検証）
- **テスト名**: `test_<対象メソッド名>_<前提条件>_<期待結果>`形式で命名
- **日本語コメント**: テストの意図・背景を明記
- **フィクスチャ活用**: pytest.fixtureでテストデータ・モックオブジェクトを共通化

### デプロイ（Lambda関数）

#### lambrollを使用したデプロイ

**設定ファイル**: `lambroll/function.json`でLambda関数の設定を管理

#### デプロイワークフロー

1. **コード品質チェック**: ruff format/check、mypy実行
2. **テスト実行**: pytestでユニット・結合テスト
3. **デプロイ準備**: lambroll deploy --dry-runで確認
4. **デプロイ実行**: lambroll deployで本番反映
5. **動作確認**: lambroll logsでログ確認

## 作業指示

**INSTRUCTIONS.md**での作業指示記載方法：

### 書き方

#### 開発ゴール

開発対象がどのようなシステムであるかを述べ、システムの設計がDESIGN.mdに定義されていることを伝える

#### 機能一覧

実装の網羅性を確保するために、DESIGN.mdで定義されたアプリケーションを基準として実装単位を定義する

各機能はapps/ディレクトリのアプリケーション名と対応し、DESIGN.mdのアプリケーション一覧で詳細仕様を参照する

#### 開発の流れ

一覧で示した機能の開発や、テストなどの検証タスクなど、開発をどのように進めるかを理由付きで説明する

例：

1. 認証機能の開発：認証情報は各機能で利用するためここで実施する
2. ○○機能：他の機能への依存がないためここで実施する
3. ××機能：依存のある○○機能の開発後に実施する
4. 開発ゴール検証：全機能の開発後に実施する

#### タスク

##### タスク分割の指針

各タスクが単独で完了判定でき、他のタスクに影響しない粒度に調整する

以下が分割の例となる

- シークレットの格納場所の作成および人手による格納を一つのタスクとする
- Lambda関数等のアプリケーションのローカル実装からユニットテストを一つのタスクとする（大きい場合は分割可能）
- IAM・ログ等を含む一つのアプリケーションの実行基盤構築とデプロイを一つのタスクとする
- 定期実行などアプリ外の機能や、アプリケーション同士の組み合わせによる機能の実現を一つのタスクとする
- 開発ゴールを満たしていることの検証を一つのタスクとする

##### タスク順序の指針

**前後関係の決定原則**：

- **機能実装の前後関係**: 単一機能の実装・テスト完了後に、その機能を利用する上位機能を実装
- **サービス間の呼び出し関係**: 呼び出し先を先に構築してから呼び出し元を構築（例：Lambda関数のデプロイ→EventBridge Schedulerの設定）
- **データフローの上流下流**: データの提供側を先に構築してから利用側を構築（例：データベース作成→アプリケーション実装）
- **機密情報**: 機密情報を先に格納してからそれを利用するサービスを構築

##### 完了条件の定義

**完了時の状態の具体化**：

- **技術的状態**: 「デプロイされている」「権限が設定されている」「テストが成功している」等の客観的な状態
- **数値基準**: カバレッジ90%以上、HTTPステータス200等の具体的な判定基準
- **設定値確認**: DESIGN.mdの仕様との一致、必要な権限の付与等

**検証方法の記載ルール**：

- **Claude Codeから実行可能**: CLIコマンド・API呼び出しのみ記載（Claude CodeはWebコンソールにアクセスできないため）
- **具体的コマンド**: `terraform apply`、`uv run pytest`、`curl [URL]`等の実際に実行するコマンドを明記
- **確認ポイント**: コマンド実行結果のどの部分を確認するかを明示（成功ステータス、設定値、レスポンス内容等）

#### 補足情報の定義

**参考情報**：

- **設計書参照**: DESIGN.mdの該当セクションを明記
- **実装ガイド参照**: CLAUDE.mdの技術セクションを明記
- **特記事項**: 実装時の注意点・制約事項を明記

**全体完了条件**：

- **機能完全性**: DESIGN.mdで定義された全機能の動作確認
- **フロー完全性**: エンドツーエンドの全体フローの成功確認
- **品質確保**: 全テストの成功とAWS環境での安定動作

### 具体例

```markdown
# 作業指示

## [機能名]システムの実装

## 開発ゴール
DESIGN.mdで定義された[システム/機能名]全体を実装し、設計書通りの完全なシステムを構築する

### 機能一覧
- **Slack連携アプリケーション (ai_interface)**: Slack Events API受信とBedrock Agent処理
- **Issue作成アプリケーション (issue_creator)**: GitHub Issue作成機能
- **Issue履歴抽出アプリケーション (issue_extractor)**: Issue履歴収集とKnowledge Base更新

## 開発の流れ
1. **認証・権限基盤の構築**: GitHub PAT管理、IAM権限設定など各アプリケーションで利用する基盤のため最初に実施
2. **Issue作成アプリケーション (issue_creator)**: 他アプリケーションへの依存が少なく単独で動作確認できるためここで実施
3. **Issue履歴抽出アプリケーション (issue_extractor)**: Issue作成アプリケーションに依存しないため並行実施可能
4. **Slack連携アプリケーション (ai_interface)**: Issue作成アプリケーションとの連携が必要なため後に実施
5. **統合テスト**: 全アプリケーションの開発完了後に全体フローを検証

## タスク

### 1. 認証・権限基盤の構築
- [ ] **GitHub PAT格納場所の作成と手動格納**: Secrets Manager作成とダミー値から実際のトークンへの置換
  - 完了条件: GitHub PATが実際の値で格納されている
  - 検証方法: Terraformでシークレット作成後、作成されたシークレットのARNまたは名前を使用してAWS CLIでシークレットの存在と値の設定状況を確認
- [ ] **IAMロール・ポリシーの作成**: Lambda実行に必要な権限設定
  - 完了条件: 必要な権限が設定されている
  - 検証方法: Terraformで作成されたIAMロール名を使用してAWS CLIでロールの存在とアタッチされたポリシーの内容を確認（Secrets Manager読み取り、Bedrock Agent実行権限等を含む）

### 2. Issue作成アプリケーション (issue_creator)
- [ ] **issue_creatorのローカル実装**: GitHub Issue作成機能の実装・テスト
  - 完了条件: ユニットテストが全て成功する
  - 検証方法: `uv run pytest --cov=src` でテスト実行し、全てPASSEDとなる
- [ ] **issue_creatorの実行基盤構築とデプロイ**: IAM・ログ等を含む実行基盤構築とデプロイ
  - 完了条件: AWS環境で正常に動作する
  - 検証方法: lambrollでデプロイ完了後、AWS CLIでLambda関数の存在とIAMロール設定、環境変数設定を確認し、テストイベントでの動作確認を実施

### 3. Issue履歴抽出アプリケーション (issue_extractor)
- [ ] **issue_extractorのローカル実装**: GitHub Issue履歴収集とS3保存の実装・テスト
  - 完了条件: ユニットテストが全て成功する
  - 検証方法: `uv run pytest --cov=src` でテスト実行し、全てPASSEDとなる
- [ ] **S3バケットとEventBridge Schedulerの構築**: データ保存基盤と定期実行設定
  - 完了条件: 指定時刻にLambda関数が自動実行される
  - 検証方法: TerraformでS3バケットとEventBridge Schedulerを作成後、AWS CLIでS3バケットの暗号化設定とスケジュールの実行設定（対象Lambda関数、実行時刻、状態）を確認
- [ ] **issue_extractorの実行基盤構築とデプロイ**: IAM・ログ等を含む実行基盤構築とデプロイ
  - 完了条件: AWS環境で正常に動作する
  - 検証方法: lambrollでデプロイ完了後、AWS CLIでLambda関数の存在と権限設定を確認し、EventBridge Schedulerからの手動実行でS3へのファイル保存動作を検証

### 4. Slack連携アプリケーション (ai_interface)
- [ ] **ai_interfaceのローカル実装**: Slack Events API処理とSessionID生成の実装・テスト
  - 完了条件: ユニットテストが全て成功する
  - 検証方法: `uv run pytest --cov=src` でテスト実行し、全てPASSEDとなる
- [ ] **ai_interfaceの実行基盤構築とデプロイ**: IAM・ログ等を含む実行基盤構築とデプロイ
  - 完了条件: AWS環境で正常に動作する
  - 検証方法: lambrollでデプロイ完了後、TerraformまたはAWS CLIでFunction URLを取得し、curlでHTTPリクエスト送信して正常なレスポンス（HTTP 200）を確認
- [ ] **Bedrock Knowledge Baseの構築**: S3データソース連携設定
  - 完了条件: Knowledge BaseがS3バケットをデータソースとして設定されている
  - 検証方法: TerraformでKnowledge Base作成後、AWS CLIでKnowledge BaseのIDを使用してデータソース設定（S3バケット連携、ベクトルエンジン設定）と状態を確認
- [ ] **Bedrock Agentの構築**: Knowledge Base連携とLambdaアクション設定
  - 完了条件: AgentがKnowledge BaseとLambda(Issue Creator)を呼び出せる
  - 検証方法: TerraformでBedrock Agent作成後、AWS CLIでAgentのIDを使用してKnowledge Base関連付け、アクショングループ設定（Lambda関数の呼び出し権限）、Agent状態を確認

### 5. 統合テスト
- [ ] **全体フロー統合テスト**: Slack→AI→GitHub Issue作成の全体フロー確認
  - 完了条件: 設計書通りの全体フローが動作する
  - 検証方法: Slack Events APIのテストペイロードをai_interfaceのFunction URLに送信し、Bedrock Agent経由でIssue作成が実行されることをCloudWatchログとGitHub APIで確認

### 参考情報
- 設計書: DESIGN.md の該当セクション（システム概要図、Issue作成、Issue履歴抽出）
- 実装ガイド: CLAUDE.md のTerraform開発・Python開発・AWS環境セクション
- 特記事項: AWS Well-Architectedセキュリティ原則の遵守、Bedrock Agent SessionID制限

### 全体完了条件
- DESIGN.mdで定義された全機能（Issue作成・Issue履歴抽出）が設計書通りに動作すること
- Slack→AI→GitHub Issue作成の全フローが成功すること
- 全てのコンポーネントの単体・結合テストが成功すること
```
