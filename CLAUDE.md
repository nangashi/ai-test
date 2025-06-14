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
└── DESIGN.md          # システム全体のアーキテクチャ設計書
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

## Terraform開発 (terraform/)

### ディレクトリ構成

```
terraform/
├── main.tf         # Providerの設定とバージョン制約
└── backend.tf      # S3バックエンド設定（ネイティブステートロック）
```

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

## Python開発 (apps/)

### ディレクトリ構成テンプレート

```
apps/<アプリ名>/
├── README.md                 # アプリケーション説明
├── DESIGN.md                 # 設計書（詳細なアーキテクチャ）
├── pyproject.toml           # プロジェクト設定
├── uv.lock                  # 依存関係ロックファイル
├── src/
│   └── main.py              # メインエントリーポイント
├── lambroll/                # Lambdaデプロイ設定
│   └── function.json        # Lambda関数設定
├── tests/                   # ユニットテスト（クラス単位）
│   ├── conftest.py          # pytest設定・フィクスチャ
│   ├── test_*.py           # 各srcファイルに対応
│   └── <ディレクトリ>/       # srcディレクトリ構造と対応
│       └── test_*.py
└── tests-it/               # 結合テスト（シナリオ単位）
    ├── conftest.py          # 結合テスト用設定
    └── test_*_scenario.py   # 業務シナリオのテスト
```

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
