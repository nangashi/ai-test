# Terraform開発ガイド

このガイドでは、本プロジェクトでのTerraform開発における標準的な構成、手順、ガイドラインを説明します。

## 環境構築

### 必要ツール

Terraformの開発・品質管理に必要なツールをaquaで統一管理：

| ツール | 用途 | aquaでのインストール |
|--------|------|---------------------|
| Terraform | Infrastructure as Code | `aqua g -i hashicorp/terraform` |
| terraform-docs | ドキュメント自動生成 | `aqua g -i terraform-docs/terraform-docs` |
| TFLint | コード品質チェック | `aqua g -i terraform-linters/tflint` |
| Trivy | セキュリティスキャン | `aqua g -i aquasecurity/trivy` |

**一括インストール**: プロジェクトルートで `aqua install` を実行

### プロジェクト初期設定

新しいTerraformプロジェクトを作成する際の初期セットアップ手順：

```bash
# 0. 必要な環境変数の設定（事前準備）
# AWS_ACCOUNT_ID: 現在のAWSアカウントID
# SYSTEM_NAME: DESIGN.mdで定義されたシステム名（例: slack-issue-system）
# TERRAFORM_VERSION: 開発開始時点の最新安定版（https://releases.hashicorp.com/terraform/ で確認）
# AWS_PROVIDER_VERSION: 開発開始時点の最新安定版（https://registry.terraform.io/providers/hashicorp/aws で確認）
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export SYSTEM_NAME="<システム名>"  # DESIGN.mdの定義に従って設定
export TERRAFORM_VERSION="1.12.2"        # 2024年12月時点の最新安定版
export AWS_PROVIDER_VERSION="5.100.0"    # 2024年12月時点の最新安定版

# 1. Terraformディレクトリの作成
mkdir -p terraform
cd terraform

# 2. providers.tfの作成
# 注意: 環境変数を展開してproviders.tfに書き込み
envsubst << 'EOF' > providers.tf
terraform {
  required_version = "= ${TERRAFORM_VERSION}"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= ${AWS_PROVIDER_VERSION}"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}
EOF

# 3. main.tfの作成（メインリソース定義用）
touch main.tf

# 4. backend.tfの作成（S3リモートステート管理）
# 注意: 環境変数を展開してbackend.tfに書き込み
envsubst << 'EOF' > backend.tf
terraform {
  backend "s3" {
    bucket         = "${AWS_ACCOUNT_ID}-tfstate"        # ステート保存バケット
    key            = "${SYSTEM_NAME}/terraform.tfstate" # システム別キー構成
    region         = "ap-northeast-1"                   # 固定リージョン
    encrypt        = true                               # 保存時暗号化
    use_lockfile   = true                              # S3ネイティブロック
  }
}
EOF

# 5. .gitignore設定（ローカルstateファイルの除外）
cat > .gitignore << 'EOF'
# Terraform
.terraform/
terraform.tfstate        # S3リモートステート使用のためローカルファイルは除外
terraform.tfstate.backup # S3リモートステート使用のためバックアップも除外
*.tfvars                 # 環境固有設定は除外（例外的にコミットする場合は個別追加）
*.tfplan
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc
EOF

# 6. terraform.tfvarsの作成（環境固有設定）
# 注意: 環境変数を展開してterraform.tfvarsに書き込み
envsubst << 'EOF' > terraform.tfvars
# 環境固有の設定値
environment = "dev"
system_name = "${SYSTEM_NAME}"
EOF

# 7. variables.tfの作成（変数定義）
cat > variables.tf << 'EOF'
variable "environment" {
  description = "環境名（dev/stg/prd）"
  type        = string
  
  validation {
    condition     = contains(["dev", "stg", "prd"], var.environment)
    error_message = "environmentは dev, stg, prd のいずれかを指定してください。"
  }
}

variable "system_name" {
  description = "システム名（DESIGN.mdで定義）"
  type        = string
  
  validation {
    condition     = length(var.system_name) > 0
    error_message = "system_nameは空でない文字列を指定してください。"
  }
}
EOF

# 8. Terraformの初期化と検証
terraform init      # バックエンド設定とプロバイダーのダウンロード
terraform validate  # 構文チェック
terraform fmt      # フォーマット適用
```

### 基本コマンド

```bash
# 作業ディレクトリに移動
cd terraform

# 初期化（初回のみ、または設定変更時）
terraform init

# 実行計画の確認
terraform plan

# 変更の適用
terraform apply

# リソースの削除
terraform destroy

# 状態の確認
terraform show
terraform state list

# ドキュメント生成
terraform-docs

# 品質チェック
terraform fmt       # コードフォーマット
terraform validate  # 構文チェック
tflint             # コード品質チェック
trivy config .     # セキュリティチェック
```

### 開発ワークフロー

標準的な開発フローを以下の順序で実施：

1. **実装前の準備**: 既存コードのフォーマット・構文チェック
2. **リソース実装**: .tfファイルでリソース定義、各ファイル最後にoutputブロック配置
3. **品質チェック**: フォーマット、構文、lint、セキュリティチェック実行
4. **計画確認と適用**: `terraform plan` → `terraform apply`
5. **ドキュメント生成**: `terraform-docs`でREADME.md自動生成
6. **動作確認**: aws cliコマンドでリソース状態確認、アプリケーション動作テスト

## 開発ガイドライン

### ファイル構成と分割方針

**ディレクトリ構成**:

```
terraform/
├── main.tf                    # メインリソース定義
├── providers.tf               # Provider設定とバージョン制約
├── backend.tf                 # S3バックエンド設定
├── variables.tf               # 入力変数定義
├── terraform.tfvars           # 環境固有の設定値
├── secrets.tf                 # Secrets Manager（共通リソース）+ outputs
├── vpc.tf                     # VPC・ネットワーク設定 + outputs
├── web_api.tf                 # Web API Lambda + IAM + Function URL + outputs
├── batch_processor.tf         # バッチ処理 Lambda + IAM + S3 + EventBridge + outputs
├── notification_service.tf    # 通知サービス Lambda + IAM + 外部サービス連携 + outputs
├── locals.tf                  # ローカル値定義（必要に応じて作成）
├── README.md                  # terraform-docsで自動生成されるドキュメント
└── modules/                   # 再利用可能なモジュール
    ├── lambda_function/
    ├── iam_role/
    └── s3_bucket/
```

**アプリケーション単位での分割**:

- 各Lambda関数とその依存リソース（IAM、S3、EventBridge等）を同一ファイルに配置
- ファイル名: `{機能名}.tf`（例: `web_api.tf`, `batch_processor.tf`）
- 各ファイルの最後に関連するoutputブロックを配置

**共通リソースの分離**:

- 複数アプリケーションで使用するリソース（Secrets Manager、VPC等）は独立ファイルに配置
- ファイル名: `{リソース種別}.tf`（例: `secrets.tf`, `vpc.tf`）
- 各ファイルの最後に関連するoutputブロックを配置

**モジュール設計の指針**:

- **単一責任**: 一つのモジュールは一つの機能・責務に特化
- **再利用性**: 環境間で共通利用できる設計
- **依存関係の最小化**: 外部モジュールへの依存は必要最小限に留める

```hcl
# モジュール例: modules/lambda_function/
# ├── main.tf          # Lambda関数リソース定義
# ├── variables.tf     # 入力変数（function_name, runtime等）
# ├── outputs.tf       # 出力値（arn, function_name等）
# └── README.md        # モジュール使用方法

# 呼び出し例
module "web_api" {
  source = "./modules/lambda_function"
  
  function_name = "web-api"
  runtime      = "python3.11"
  memory_size  = 512
  
  tags = local.common_tags
}
```

**ドキュメント生成**:

- `terraform-docs`コマンドでREADME.mdを自動生成
- 全てのoutput値の一覧と説明を自動でドキュメント化

### 設定ファイルの使い分け

**Variables（variables.tf）**:

- **用途**: 外部から注入される値、環境間で変わる値の定義
- **作成タイミング**: プロジェクト初期設定時に必須ファイルとして作成
- **バリデーション**: 必須でvalidationルールを設定

**環境固有設定（terraform.tfvars）**:

- **用途**: variables.tfで定義した変数の実際の値を設定
- **環境別管理**: dev.tfvars、stg.tfvars、prd.tfvarsでの環境分離
- **機密性**: 機密情報は含めず、環境識別子のみを設定

**変数定義の必須要素**:

```hcl
variable "lambda_configs" {
  description = "Lambda関数の設定一覧"
  type = map(object({
    name      = string
    timeout   = number
    memory_size = number
    env_vars  = map(string)
  }))

  validation {
    condition = alltrue([
      for k, v in var.lambda_configs : 
      v.timeout >= 3 && v.timeout <= 900
    ])
    error_message = "timeoutは3-900秒の範囲で設定してください。"
  }

  validation {
    condition = alltrue([
      for k, v in var.lambda_configs : 
      v.memory_size >= 128 && v.memory_size <= 10240
    ])
    error_message = "memory_sizeは128-10240MBの範囲で設定してください。"
  }
}
```

**型定義の指針**:

- **具体的な型を使用**: `any`型は避け、`string`、`number`、`bool`、`list(type)`、`map(type)`、`object({})`を明示
- **複合型の構造化**: オブジェクト型で設定グループを構造化
- **バリデーション設定**: 値の範囲、形式、必須条件をvalidationブロックで検証

**Locals（locals.tf）**:

- **用途**: 計算ロジック、命名パターン、共通設定の集約
- **作成タイミング**: リソース名の統一や共通タグが必要になった時点で作成
- **構成**: 用途別にコメントで分類し、保守性を向上

**タグ付け戦略**:

```hcl
# locals.tf内での標準タグ定義
locals {
  # 全リソース共通タグ
  common_tags = {
    Environment = var.environment        # dev/stg/prd
    System     = var.system_name        # DESIGN.mdで定義されたシステム名
    ManagedBy  = "terraform"            # 管理方法
    Project    = "slack-issue-system"   # プロジェクト名
  }
  
  # コンポーネント別タグ（必要に応じて）
  lambda_tags = merge(local.common_tags, {
    Component = "compute"
    Runtime   = "python3.11"
  })
  
  storage_tags = merge(local.common_tags, {
    Component = "storage"
    BackupRequired = "true"
  })
}

# リソースでの使用例
resource "aws_lambda_function" "web_api" {
  function_name = "web-api"
  
  tags = local.lambda_tags  # コンポーネント固有タグ
}

resource "aws_s3_bucket" "data_storage" {
  bucket = "data-storage"
  
  tags = local.storage_tags  # コンポーネント固有タグ
}
```

**タグ設定の必須要素**:
- **Environment**: 環境識別（dev/stg/prd）
- **System**: システム名（DESIGN.mdに準拠）
- **ManagedBy**: 管理方法（terraform固定）
- **Project**: プロジェクト名

### 命名規則

**AWSリソース名**:

[AWS環境ガイド](aws.md)の命名規則に準拠

**Terraformリソース名**:

```hcl
# リソース名: {リソース種別}_{機能名}_{詳細}
resource "aws_lambda_function" "web_api_handler" {}
resource "aws_iam_role" "web_api_execution" {}
resource "aws_s3_bucket" "batch_processor_storage" {}

# データソース名: {リソース種別}_{用途}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
```

**データソースの配置規則**:

- **配置場所**: 使用するリソースと同じファイルに配置
- **命名規則**: `data.aws_{サービス名}_{用途}`形式で統一
- **配置順序**: ファイル内でリソース定義の前に配置

```hcl
# web_api.tf内での配置例
# 1. データソース（ファイル先頭）
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_secretsmanager_secret_version" "github_pat" {
  secret_id = "dev-github-pat"
}

# 2. リソース定義
resource "aws_iam_role" "web_api_execution" {
  name               = "${local.name_prefix}-web-api-execution"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_lambda_function" "web_api_handler" {
  function_name = "web-api-handler"
  role         = aws_iam_role.web_api_execution.arn
  
  environment {
    variables = {
      GITHUB_TOKEN = data.aws_secretsmanager_secret_version.github_pat.secret_string
    }
  }
}
```

**Variables命名**:

- **形式**: `{用途}` のスネークケース
- **必須要素**: description、type、validation
- **例**: `environment`、`system_name`、`lambda_timeout`

**Locals命名**:

- **共通設定**: `common_{設定種別}` 形式（例: `common_tags`）
- **命名プレフィックス**: `{用途}_prefix` 形式（例: `name_prefix`）
- **リソース名**: `{リソース種別}_{機能名}_{詳細}` 形式（例: `lambda_function_name`）
- **計算値**: 用途を表す分かりやすい名前（例: `tfstate_bucket`）

**Outputs（各.tfファイル内）**:

各リソース定義ファイルの最後にoutputブロックを配置:

```hcl
# web_api.tfの例
resource "aws_lambda_function" "web_api_handler" {
  # ... リソース定義
}

# このファイルのoutputは最後にまとめて配置
output "web_api_function_arn" {
  description = "ARN of the Web API Lambda function"
  value       = aws_lambda_function.web_api_handler.arn
}

output "web_api_function_url" {
  description = "Function URL of the Web API"
  value       = aws_lambda_function_url.web_api.function_url
  sensitive   = false
}
```

### コメント記述規則

- **ファイルヘッダー**: 機能概要と含まれるリソースを記載
- **リソース**: 用途と設定理由を簡潔に説明
- **設定値**: 非自明な値は設定理由をコメント

### リソース定義のベストプラクティス

**属性の記述順序**:

```hcl
resource "aws_lambda_function" "example" {
  # 1. count/for_each（複数リソース作成時）
  for_each = var.lambda_configs

  # 2. 必須属性
  function_name = each.value.name
  role         = aws_iam_role.execution.arn
  handler      = "main.lambda_handler"
  runtime      = "python3.11"

  # 3. オプション属性（非ブロック）
  filename         = "deployment.zip"
  source_code_hash = filebase64sha256("deployment.zip")
  timeout          = each.value.timeout
  memory_size      = each.value.memory_size

  # 4. ブロック設定
  environment {
    variables = each.value.env_vars
  }

  vpc_config {
    subnet_ids         = local.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  # 5. ライフサイクル管理
  lifecycle {
    prevent_destroy = true
  }

  # 6. 依存関係
  depends_on = [aws_iam_role_policy_attachment.lambda_execution]

  # 7. タグ（最後）
  tags = local.common_tags
}
```

**依存関係の明示規則**:

- **暗黙的依存で十分な場合**: depends_on不要（リソース参照で自動解決）
- **depends_on使用が必要な場合**: 作成・削除順序の制御が重要な場合

```hcl
# depends_on不要（暗黙的依存で十分）
resource "aws_lambda_function" "example" {
  function_name = "example"
  role         = aws_iam_role.execution.arn  # 暗黙的依存
}

# depends_on必要（IAMポリシーアタッチ完了後にLambda作成）
resource "aws_lambda_function" "processor" {
  function_name = "data-processor"
  role         = aws_iam_role.execution.arn
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_vpc_access
  ]
}
```

**複数リソース作成の指針**:

- **for_each推奨**: 個別のリソース管理が必要な場合
- **count使用**: 同一設定の単純な複製のみ

```hcl
# 推奨: for_each（個別設定可能）
resource "aws_lambda_function" "handlers" {
  for_each = {
    api     = { memory = 512, timeout = 30 }
    batch   = { memory = 1024, timeout = 300 }
  }
  
  function_name = "app-${each.key}"
  memory_size   = each.value.memory
  timeout       = each.value.timeout
}

# 限定使用: count（同一設定のみ）
resource "aws_subnet" "private" {
  count           = length(var.availability_zones)
  vpc_id          = aws_vpc.main.id
  cidr_block      = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.availability_zones[count.index]
}
```

### 機密情報の取り扱い

```hcl
# 推奨: Secrets Managerからdata sourceで参照
data "aws_secretsmanager_secret_version" "github_pat" {
  secret_id = "dev-github-pat"
}

locals {
  github_token = data.aws_secretsmanager_secret_version.github_pat.secret_string
}

resource "aws_lambda_function" "issue_creator" {
  function_name = "issue-creator"
  
  environment {
    variables = {
      GITHUB_TOKEN = local.github_token  # data sourceから参照
    }
  }
}

# 禁止: variableでの機密情報受け取り
variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
  # ❌ 機密情報をvariableで受け取るのは禁止
}
```

**機密情報取り扱い方針**:
- **Secrets Manager**: data sourceで参照（推奨）
- **環境変数**: 非機密の設定値のみvariableで受け取り
- **ハードコード**: すべての機密情報で禁止

**必須設定項目**:

- すべてのリソースに`tags = local.common_tags`を設定
- リソース名は`local`値を使用して一貫性を保つ
- 機密性の高い設定は`sensitive = true`を指定

## 品質管理

### コード品質チェック

詳細オプション：

```bash
# 再帰的フォーマット
terraform fmt -recursive

# 詳細な実行計画検証
terraform plan -detailed-exitcode
```

**TFLint設定（.tflint.hcl）**:

```hcl
plugin "aws" {
  enabled = true
  version = "0.24.1"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "aws_resource_missing_tags" {
  enabled = true
  tags = ["Environment", "System", "ManagedBy"]
}
```

**TFLint実行**:

```bash
# TFLintの実行
tflint

# 設定ファイル指定
tflint --config=.tflint.hcl

# 特定ルールのみ実行
tflint --enable-rule=aws_resource_missing_tags
```

### セキュリティ検証

```bash
# セキュリティスキャン実行
trivy config .

# JSON形式で詳細結果出力
trivy config --format json --output security-report.json .

# 特定の重要度以上のみ表示
trivy config --severity HIGH,CRITICAL .
```

**検証項目**:

- IAM権限設定の適切性
- 暗号化設定の有効性
- 機密情報の適切な取り扱い
- ネットワーク分離の実装

詳細は[AWS環境ガイド](aws.md)の設計指針と開発ガイドラインの機密情報の取り扱いを参照

### バージョン管理

**基本方針**:

- 開発開始時点の最新安定版で完全固定（プロジェクト初期設定で環境変数として定義）
- バージョン変更による予期しない動作変更を防ぎ、開発環境の一貫性を保つ

**実装前確認**: MCPサーバーでTerraform・AWSプロバイダーの最新仕様を確認

**アップデート方針**:

- **パッチバージョン**: セキュリティ修正等の重要な場合のみ検証後に更新
- **マイナー・メジャーバージョン**: プロジェクト完了後の次期開発時に検討

**バージョン更新手順**:

1. プロジェクト初期設定の環境変数を更新
2. `envsubst`でproviders.tfを再生成
3. チーム全体で同じバージョンに統一

### State管理方針

**必須原則**:

- **S3リモートステート**: 全てのTerraformプロジェクトで必ずS3バックエンドを使用
- **ローカルstate禁止**: `terraform.tfstate`ファイルのローカル管理は一切行わない
- **バージョン管理除外**: ローカルstateファイルは`.gitignore`で必ず除外

**State操作の制限**:

- `terraform state`コマンドの直接実行は原則禁止
- State変更が必要な場合は事前に影響範囲を確認
- State破損時は`terraform import`での復旧を優先

**チーム開発での注意**:

- 複数人での同時実行を避ける（S3ロックファイルで制御）
- `terraform apply`実行前は必ず`terraform plan`で変更確認

## 参考情報

- **AWS環境**: [AWS環境ガイド](aws.md)
- **設計書**: [DESIGN.md](../../DESIGN.md)
