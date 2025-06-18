# AWS環境ガイド

このガイドでは、本プロジェクトでのAWS環境における基本方針、命名規則、設計指針について説明します。

## 基本方針

- **Terraformで構築する**: AWSリソースの作成・管理はTerraformを使用してInfrastructure as Codeで実施
- **Lambdaはlambrollでデプロイする**: Lambda関数のデプロイ・管理はlambrollを使用して実施
- **Secrets Managerはデフォルトでdummyという文字列を格納し、手動で値を書き換える**: セキュリティ上、初期値はプレースホルダーとして設定
- **開発コンテナ内では認証設定済み**: 開発コンテナ内ではAWS認証が構成済みのため、AWS CLIやTerraformの認証設定は不要

## 命名規則

### リソース命名パターン

**組み合わせリソース**: 他のリソースと組み合わせて使用するもの

- 形式: `{env}-{リソース名}-{役割}`
- 対象: VPC、IAM Role/Policy、セキュリティグループ、サブネット等
- 例: `dev-vpc-main`、`dev-role-lambda_execution`、`dev-policy-lambda_execution`、`dev-sg-web_server`

**単独リソース**: 単独で動作するもの

- 形式: `{env}-{役割}`
- 対象: ECS、Lambda、RDS、S3バケット等
- 例: `dev-api_server`、`dev-batch_processor`
- ただしS3はハイフンしか利用できないためすべてハイフン区切りとする

### 命名規則詳細

- **環境**: `dev`、`stg`、`prd`
- **役割の複数単語**: アンダースコア区切り（例: `web_server`、`data_processor`）
- **英小文字**: 全て小文字で統一
- **略語**: 一般的な略語を使用（`sg` = Security Group、`rds` = RDS等）

## 設計指針

**AWS Well-Architectedフレームワーク**に従って設計・実装を行う。特にセキュリティは重要なため以下を遵守：

- **最小権限の原則**: IAMロールは必要最小限の権限のみ付与
- **シークレット管理**: Secrets Managerを使用してAPI Token・パスワード等を管理
- **暗号化**: S3ステートファイル、Knowledge Base等の保存時暗号化を有効化
- **VPC内配置**: Lambda関数は可能な限りVPC内に配置してネットワーク分離

## 参考情報

- **設計書**: [DESIGN.md](../../DESIGN.md)