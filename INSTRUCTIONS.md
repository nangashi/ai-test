# 作業指示書

## Slack Issue起票システム構築

## 概要
DESIGN.mdで定義されたSlack Issue起票システムを段階的に実装する作業指示書です。

### 対象アプリケーション
- **AI Interface (ai_interface)**: Slack Events APIからBedrock Agentへの橋渡し
- **Issue作成 (issue_creator)**: GitHub Issue起票の実行
- **Issue履歴抽出 (issue_extractor)**: Issue履歴収集とKnowledge Base更新

## 実装順序
1. **共通基盤の構築**: GitHub PAT管理、基本的なTerraformリソース設定
2. **Issue作成アプリケーション (issue_creator)**: Issue起票機能の実装とデプロイ
3. **Issue履歴抽出アプリケーション (issue_extractor)**: GitHub APIからS3への履歴収集機能
4. **AI Interface前提条件の準備**: Knowledge Base作成、Bedrock Agent設定
5. **AI Interfaceアプリケーション (ai_interface)**: Issue起票要求をBedrock Agent経由で処理
6. **統合テスト**: 全体システムの動作確認

## 作業詳細

### 1. 共通基盤の構築
- [x] **GitHub PAT格納場所の作成**: Secrets Managerの作成とダミー値設定
  - 完了条件: Secrets Managerにダミー値が格納されている
  - 検証方法: `aws secretsmanager get-secret-value`コマンドでSecretStringが"dummy"であることを確認
- [ ] **GitHub PAT実値設定**: 実際のGitHub PATの手動設定
  - 完了条件: GitHub PATが実際の値で格納されている
  - 検証方法: 
    1. 人による作業を依頼（GitHubでPersonal Access Token生成し、`aws secretsmanager update-secret`コマンドで更新）
    2. 完了報告後に`aws secretsmanager get-secret-value`でSecretStringが"dummy"でないことを確認
    3. SecretStringの長さが40文字以上であることを確認
    4. `curl -H "Authorization: token <PAT>" https://api.github.com/user`でHTTPステータス200が返されることを確認

### 2. Issue作成アプリケーション (issue_creator)
- [x] **issue_creatorの実装**: GitHub Issue起票処理の実装
  - 完了条件: ユニットテストが全て成功する
  - 検証方法: `uv run pytest --cov=src` でテスト実行し、出力に"FAILED"が含まれず、全テストが"PASSED"と表示され、カバレッジが90%以上であることを確認
- [x] **issue_creatorのインフラ構築**: Lambda関数とIAM権限をTerraformで作成
  - 完了条件: Lambda関数が正常なIAM権限と共に作成される
  - 検証方法: 
    1. `terraform apply`コマンドが終了コード0で完了することを確認
    2. `aws iam list-attached-role-policies`でポリシーが1つ以上アタッチされることを確認
    3. `aws iam get-policy-version`でAction配列に"secretsmanager:GetSecretValue"が含まれることを確認
    4. `aws lambda get-function`でStateが"Active"であることを確認
- [ ] **issue_creatorのデプロイ**: lambrollを使用したデプロイ
  - 完了条件: AWSへの実際のデプロイが完了している
  - 検証方法: 
    1. `lambroll deploy`コマンドが終了コード0で完了することを確認
    2. `aws lambda get-function`でStateが"Active"であることを確認
    3. `aws lambda get-function`のConfiguration.RoleがIAMロールのARNと一致することを確認
    4. `aws lambda invoke --function-name issue_creator`でHTTPステータス200が返されることを確認

### 3. Issue履歴抽出アプリケーション (issue_extractor)
- [ ] **issue_extractorの実装**: GitHub Issue履歴収集とS3保存の実装
  - 完了条件: ユニットテストが全て成功する
  - 検証方法: `uv run pytest --cov=src` でテスト実行し、出力に"FAILED"が含まれず、全テストが"PASSED"と表示され、カバレッジが90%以上であることを確認
- [ ] **issue_extractorのインフラ構築**: Lambda、IAM、S3、EventBridge SchedulerをTerraformで作成
  - 完了条件: Lambda関数、S3バケット、EventBridge Schedulerが正常に作成される
  - 検証方法: 
    1. `terraform apply`コマンドが終了コード0で完了することを確認
    2. `aws s3api get-bucket-encryption`でEncryption.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithmが"AES256"であることを確認
    3. `aws scheduler get-schedule`でStateが"ENABLED"であることを確認
    4. `aws iam get-policy-version`でAction配列に"s3:PutObject"と"bedrock:StartIngestionJob"が含まれることを確認
- [ ] **issue_extractorのデプロイ**: lambrollを使用したデプロイ
  - 完了条件: AWSへの実際のデプロイが完了している
  - 検証方法: 
    1. `lambroll deploy`コマンドが終了コード0で完了することを確認
    2. `aws lambda get-function`でStateが"Active"であることを確認
    3. `aws lambda invoke --function-name issue_extractor`でHTTPステータス200が返されることを確認
    4. `aws s3 ls`でS3バケットに"*.md"ファイルが1つ以上存在することを確認
- [ ] **EventBridge Schedulerの動作確認**: 定期実行スケジュールのテスト
  - 完了条件: スケジュールが正常に作成され実際のLambda関数を呼び出す
  - 検証方法: 
    1. `aws scheduler get-schedule`でScheduleExpressionが"cron(0 16 * * ? *)"であることを確認
    2. `aws logs filter-log-events`で過去24時間以内にLambda実行ログが存在することを確認
    3. ログに"SUCCESS"が含まれ、"ERROR"が含まれないことを確認

### 4. AI Interface前提条件の準備
- [ ] **Knowledge Base用データソースの準備**: S3バケットにサンプルMarkdownファイルの配置
  - 完了条件: S3バケットがKnowledge Base用のデータソースを持つ
  - 検証方法: 
    1. `aws s3 ls`でS3バケットに"sample-issue-123.md"ファイルが存在することを確認
    2. `aws s3api head-object`でファイルサイズが100バイト以上であることを確認
    3. `aws s3 cp`でファイルをダウンロードし、先頭に"---"で始まるfrontmatterが含まれることを確認
    4. ファイル内容にDESIGN.mdで定義されたフィールド（issue_number、title、state）が含まれることを確認
- [ ] **Bedrock Agent用OpenAPI Schemaファイルの作成**: Lambda関数呼び出し用のAPI定義
  - 完了条件: OpenAPI Schema JSONファイルがBedrock Agent設定に使用可能な状態で作成される
  - 検証方法:
    1. 指定パス（`terraform/schemas/issue-creator-api.json`）にファイルが存在することを確認
    2. `jq '.' terraform/schemas/issue-creator-api.json` でパースエラーが発生しないことを確認
    3. `jq '.openapi' terraform/schemas/issue-creator-api.json` で"3.0.0"以上のバージョンが返されることを確認
    4. `jq '.paths | keys | length' terraform/schemas/issue-creator-api.json` で1つ以上のパスが定義されることを確認
    5. `jq '.paths["/create-issue"].post.parameters | length' terraform/schemas/issue-creator-api.json` で4つ以上のパラメータ（repository、title、body、labels）が定義されることを確認

### 5. AI Interfaceアプリケーション (ai_interface)
- [ ] **ai_interfaceの実装**: Slack Events API受信とSessionID生成の実装
  - 完了条件: ユニットテストが全て成功する
  - 検証方法: `uv run pytest --cov=src` でテスト実行し、出力に"FAILED"が含まれず、全テストが"PASSED"と表示され、カバレッジが90%以上であることを確認
- [ ] **ai_interfaceのインフラ構築**: Lambda、IAM、Bedrock Agent、Knowledge BaseをTerraformで作成
  - 完了条件: Lambda関数、Bedrock Agent、Knowledge Baseが正常に作成される
  - 検証方法: 
    1. `terraform apply`コマンドが終了コード0で完了することを確認
    2. `aws bedrock-agent get-knowledge-base`でStatusが"ACTIVE"であることを確認
    3. `aws bedrock-agent get-agent`でAgentStatusが"NOT_PREPARED"または"PREPARED"であることを確認
    4. `aws iam get-policy-version`でAction配列に"bedrock:InvokeAgent"が含まれることを確認
- [ ] **Knowledge BaseのIngestion Job実行**: データソースの取り込み処理
  - 完了条件: Knowledge Baseがデータソースを取り込み済みである
  - 検証方法: 
    1. `aws bedrock-agent start-ingestion-job`コマンドが正常実行されることを確認
    2. 30秒後に`aws bedrock-agent get-ingestion-job`でStatusを確認
    3. Statusが"COMPLETE"になるまで待機（最大15分）
    4. `aws bedrock-agent list-data-sources`でDocumentCountが1以上であることを確認
- [ ] **Bedrock Agentの準備とAlias作成**: Agent用の動作準備
  - 完了条件: Agent AliasがREADYな状態で動作準備ができる
  - 検証方法: 
    1. `aws bedrock-agent prepare-agent`コマンドが正常実行されることを確認
    2. `aws bedrock-agent create-agent-alias`でAliasを作成
    3. `aws bedrock-agent get-agent-alias`でAliasStatusが"READY"であることを30秒後に確認
    4. AgentStatusが"PREPARED"であることを確認
- [ ] **ai_interfaceのデプロイ**: lambrollを使用したデプロイ
  - 完了条件: AWSへの実際のデプロイが完了している
  - 検証方法: 
    1. `lambroll deploy`コマンドが終了コード0で完了することを確認
    2. `aws lambda get-function`でStateが"Active"であることを確認
    3. `aws lambda get-function-url-config`でFunctionUrlが存在することを確認
    4. `curl -X POST <FunctionUrl>`でHTTPステータス200が返されることを確認

### 6. 統合テスト
- [ ] **Issue作成統合テスト**: SlackからBedrock Agent経由GitHub Issue作成の全体確認
  - 完了条件: Slack入力から最終的なGitHub Issue作成まで実行できる
  - 検証方法: 
    1. `curl -X POST <FunctionUrl>`でSlack Events APIのテストペイロード（app_mentionイベント）を送信
    2. HTTPステータス200が返されることを確認
    3. レスポンスボディが有効なJSON形式であることを確認
    4. `curl -H "Authorization: token <PAT>" https://api.github.com/repos/<owner>/<repo>/issues`で新しいIssueが作成されることを確認
- [ ] **Issue履歴抽出統合テスト**: GitHubからS3、Knowledge Baseへの流れ
  - 完了条件: issue_extractorが実際にIssue履歴を保存し、Knowledge Base更新する
  - 検証方法: 
    1. `aws lambda invoke --function-name issue_extractor`コマンドを実行
    2. `aws s3 ls`でS3バケットに新しい"*.md"ファイルが1つ以上保存されることを確認
    3. `aws s3 cp`でファイルをダウンロードし、frontmatterを含むMarkdown形式であることを確認
    4. `aws bedrock-agent start-ingestion-job`で新しいIngestion Jobが正常実行されることを確認
- [ ] **全体動作確認**: 完全なSlackワークフローの実行
  - 完了条件: 完全なSlackから開始するIssue作成を実行する
  - 検証方法: 
    1. 人による検証を依頼（実際のSlackワークスペースでBotにメンション送信）
    2. GitHubリポジトリに新しいIssueが作成され、Issue番号が増加することを確認
    3. Issueの内容（title、body、labels）がSlackメッセージの内容に基づいて作成されることを確認
    4. `aws logs filter-log-events`でLambda実行ログに"SUCCESS"が含まれ、"ERROR"が含まれないことを確認

### 参考資料
- 基本方針: DESIGN.md の概要、特徴、システム概要図、処理シーケンス
- 実装ルール: CLAUDE.md のTerraform規約、Python規約、AWS設定ガイドライン
- 検証基準: CLAUDE.md の作業指示ガイドライン、品質基準、段階的検証方法
- セキュリティ: AWS Well-Architected原則に基づくセキュリティ実装、Bedrock Agent SessionID制約

### 完成基準
- DESIGN.mdで定義されたアプリケーション（ai_interface、issue_creator、issue_extractor）を実装済みであること
- SlackからAI経由GitHub Issue作成の全体フローが動作すること
- 全てのコンポーネントの統合テストが成功すること