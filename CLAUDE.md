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
- ホストシステムからのSSHとGit設定の共有
- コンテナ開発のためのDocker-in-Docker対応
- `aqua.yaml`で設定されたツールのバージョン管理
- パスに`$HOME/.local/share/aquaproj-aqua/bin`が含まれAqua管理のバイナリが利用可能

## Terraform開発

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
