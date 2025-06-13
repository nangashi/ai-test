# CLAUDE.md

このファイルはClaude Code (claude.ai/code) がこのリポジトリで作業する際のガイダンスを提供します。

## 基本方針

- 対話ではすぐに実装しない。実装方針を提示して合意してから進める

## プロジェクト構成

`terraform/`以下にInfrastructure as Codeを配置したモノレポ構成：

- `terraform/` - Terraformを使用したインフラストラクチャ定義

## 開発環境

このプロジェクトはDockerベースの開発コンテナを使用して一貫した開発環境を提供します：

- VS Code/Cursor統合のDev Container設定
- AquaパッケージマネージャーによるCLIツールのバージョン管理
- コンテナ開発のためのDocker-in-Docker対応

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
- **コード品質**: 実装後に`tflint`を実行して問題を特定・解決する
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
```

### 技術スタック

#### 推奨ライブラリ

- **uv**: パッケージマネージャー（高速な依存関係管理）
- **ruff**: コードフォーマッター・リンター
- **mypy**: 静的型チェッカー
- **pytest**: テストフレームワーク
- **injector**: 依存性注入フレームワーク
- **polars**: 高速データ処理エンジン（データ処理アプリの場合）
- **tenacity**: エラーリトライライブラリ

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
