# システム設計

## 概要

AWS Bedrockを活用したSlackベースのIssue起票システム。ユーザーがSlackから依頼すると過去のIssue履歴を参照しつつAIが適切なIssueを自動生成することで、ユーザーのIssue作成の負担を軽減します。

主な特徴：

- **Slack連携**: メンションベースの直感的なIssue作成インターフェース
- **AI支援**: 過去のIssue履歴を参照した適切なIssue内容の自動生成
- **対話式修正**: プレビュー確認と修正依頼による段階的なIssue精度向上
- **自動学習**: クローズ済みIssueの日次収集によるナレッジベース更新

## システム設計

### 機能一覧

| 機能名 | 概要 |
|--------|------|
| Issue作成機能 | ユーザーからの依頼によりAIが過去履歴を参考にしながらGitHub Issueを自動生成する機能 |
| Issueナレッジ機能 | GitHub Issue履歴を収集・蓄積してAI学習用ナレッジベースを構築する機能 |

### 機能関連図

```mermaid
graph LR
    U((User)) -->|Issue作成依頼| IC[Issue作成機能]
    IC -->|Issue作成| GH[GitHub]

    GH -->|Issue履歴取得| INF[Issueナレッジ機能]
    INF -->|ナレッジ蓄積| IC
```

## アーキテクチャ

```mermaid
graph TB
    U((User))
    S[Slack]
    GH[GitHub]

    subgraph "Issue作成機能"
        AI["AI Interface<br/>(ai_interface)"]
        IC["Issue Creator<br/>(issue_creator)"]
        BA{Bedrock Agent}
    end

    subgraph "Issueナレッジ機能"
        ES[EventBridge Scheduler]
        IE["Issue Extractor<br/>(issue_extractor)"]
        S3[S3]
    end

    subgraph "共有リソース"
        KB[("Knowledge Base")]
        SM[Secrets Manager]
    end

    U -->|Issue作成依頼| S
    S -->|イベントコール| AI
    AI -->|クエリ| BA
    BA -->|アクション| IC
    IC -->|Issue作成| GH
    BA -->|Issue提案| AI
    AI -->|Issue提案| S
    S -->|Issue提案| U

    ES -->|日次トリガー| IE
    IE -->|Issue履歴取得| GH
    IE -->|データ保存| S3

    BA <-->|Issue履歴参照| KB
    S3 -->|ナレッジ蓄積| KB

    IC -->|PAT取得| SM
    IE -->|PAT取得| SM
```

## 機能シーケンス

### Issue作成機能

```mermaid
sequenceDiagram
    participant U as User
    participant S as Slack
    participant IC as Issue作成機能
    participant AN as AIナレッジ
    participant GH as GitHub

    U->>S: Issue作成依頼
    S->>IC: イベントコール
    IC->>AN: Issue履歴参照
    AN->>IC: 関連データ
    IC->>IC: Issue内容生成
    IC->>S: Issue提案
    S->>U: Issue提案

    alt 修正依頼の場合
        U->>S: 修正指示
        S->>IC: 修正イベントコール
        IC->>IC: Issue内容修正
        IC->>S: 修正Issue提案
        S->>U: 修正Issue提案
    end

    U->>S: 最終承認
    S->>IC: 承認イベントコール
    IC->>GH: Issue作成
    GH->>IC: 作成完了
    IC->>S: 完了通知
    S->>U: 作成完了情報
```

### Issueナレッジ機能

```mermaid
sequenceDiagram
    participant ES as EventBridge Scheduler
    participant INF as Issueナレッジ機能
    participant GH as GitHub
    participant AN as AIナレッジ

    ES->>INF: 日次トリガー
    INF->>GH: Issue履歴取得
    GH->>INF: Issue履歴データ
    INF->>INF: データ処理・構造化
    INF->>AN: ナレッジ蓄積
    AN->>INF: 蓄積完了
```

## アプリケーション一覧

### issue_creator

#### 概要

GitHub Issue作成を実行するLambda関数

#### デプロイ先

AWS Lambda（Bedrock Agentからのアクション呼び出し用）

#### 入力

Bedrock Agentからのアクション呼び出し時のJSONペイロード：

```json
// Bedrock Agentからの入力
{
  "messageVersion": "string",
  "agent": {
    "name": "string",
    "id": "string",
    "alias": "string",
    "version": "string"
  },
  "inputText": "string",
  "sessionId": "string",
  "actionGroup": "string",
  "apiPath": "string",
  "httpMethod": "string",
  "parameters": [
    {
      "name": "repository",
      "type": "string",
      "value": "string"
    },
    {
      "name": "title",
      "type": "string",
      "value": "string"
    },
    {
      "name": "body",
      "type": "string",
      "value": "string"
    },
    {
      "name": "labels",
      "type": "array",
      "value": "string" // JSON配列文字列
    }
  ]
}
```

#### 処理

Bedrock Agentからのアクション呼び出しを受けて、Secrets ManagerからGitHub PATを取得し、GitHub API経由でIssueを作成して結果を返却します。

```mermaid
sequenceDiagram
    participant BA as Bedrock Agent
    participant L2 as Lambda<br/>(Issue Creator)
    participant SM as Secrets Manager
    participant GH as GitHub

    BA->>L2: アクション実行 (issue data)
    L2->>SM: PAT取得要求
    SM->>L2: PAT返却
    L2->>GH: Issue作成
    GH->>L2: Issue作成完了 (URL付き)
    L2->>BA: 作成完了応答
```

#### 出力

Bedrock Agentへのレスポンス：

```json
// Bedrock Agentへの出力
{
  "messageVersion": "1.0",
  "response": {
    "actionGroup": "issue-creator",
    "apiPath": "/create-issue",
    "httpMethod": "POST",
    "httpStatusCode": 200,
    "responseBody": {
      "application/json": {
        "body": "{\"issue_url\": \"GitHub Issue URL\", \"issue_number\": 123, \"status\": \"created\"}"
      }
    }
  }
}

### AI Interface (ai_interface)

#### 概要

Slack Events APIを受信してBedrock Agentとやり取りするLambda関数

#### デプロイ先

AWS Lambda（Function URL有効化でSlack連携）

#### 入力

Slack Events APIからのapp_mentionイベント：

```json
// Slackからの入力
{
  "token": "認証トークン",
  "team_id": "Slackワークスペース ID",
  "api_app_id": "Slack アプリ ID",
  "event": {
    "type": "app_mention",
    "user": "メンションしたユーザー ID",
    "text": "メンション内容テキスト",
    "ts": "メッセージタイムスタンプ",
    "channel": "チャンネル ID",
    "event_ts": "イベントタイムスタンプ",
    "thread_ts": "スレッドタイムスタンプ（オプション）"
  },
  "type": "event_callback",
  "event_id": "イベント ID",
  "event_time": "Unix時刻",
  "authed_users": ["認証済みユーザー ID"]
}
```

#### 処理

Slack Events APIからのapp_mentionイベントを受信し、SessionIDを生成してBedrock Agentとやり取りを行い、応答をSlackに転送します。

```mermaid
sequenceDiagram
    participant U as User
    participant S as Slack
    participant L1 as Lambda<br/>(AI Interface)
    participant BA as Bedrock Agent
    participant KB as Bedrock Knowledge Base
    participant L2 as Lambda<br/>(Issue Creator)
    participant SM as Secrets Manager
    participant GH as GitHub

    U->>S: メンション/依頼
    S->>L1: イベント送信 (Function URL)
    Note over L1: SessionID生成
    L1->>BA: クエリ送信 (sessionId)
    BA->>KB: ナレッジ検索
    KB->>BA: 関連データ
    BA->>L1: Issue内容生成
    L1->>S: プレビュー送信
    S->>U: プレビュー表示

    alt 修正依頼の場合
        U->>S: 修正依頼
        S->>L1: 修正イベント
        L1->>BA: 修正リクエスト (same sessionId)
        Note over BA: 会話履歴保持
        BA->>L1: 修正されたIssue内容
        L1->>S: 更新プレビュー送信
        S->>U: 更新プレビュー表示
    end

    U->>S: 最終承認
    S->>L1: 承認イベント
    L1->>BA: Issue作成リクエスト (same sessionId)
    BA->>L2: アクション実行 (issue data)
    L2->>SM: PAT取得要求
    SM->>L2: PAT返却
    L2->>GH: Issue作成
    GH->>L2: Issue作成完了 (URL付き)
    L2->>BA: 作成完了応答
    BA->>L1: 応答
    L1->>S: 成功通知 (URL付き)
    S->>U: 作成完了情報 (URL付き)
```

#### 出力

Slackへの応答（HTTP 200 OK）：

```json
// Slackへの応答
{
  "statusCode": 200,
  "headers": {
    "Content-Type": "application/json"
  },
  "body": "OK"
}
```

Slack APIへのメッセージ投稿：

```json
// Slackメッセージ投稿
{
  "channel": "チャンネル ID",
  "text": "投稿メッセージテキスト",
  "thread_ts": "返信先スレッドタイムスタンプ（オプション）"
}
```

### Issue履歴抽出 (issue_extractor)

#### 概要

GitHub Issue履歴を定期収集してS3保存・Knowledge Base更新するLambda関数

#### デプロイ先

AWS Lambda（EventBridge Schedulerから日次実行）

#### 入力

EventBridge Schedulerからの定期実行時の入力：

```json
// EventBridgeからの入力
{
  "version": "0",
  "id": "イベント ID",
  "detail-type": "Scheduled Event",
  "source": "aws.scheduler",
  "account": "AWSアカウント ID",
  "time": "実行時刻（ISO 8601）",
  "region": "ap-northeast-1",
  "resources": ["スケジューラーARN"],
  "detail": {
    "target_date": "処理対象日（オプション）"
  }
}
```

#### 処理

EventBridge Schedulerからの日次実行により、前日クローズのIssue履歴をGitHub APIから取得し、Frontmatter Markdown形式でS3に保存してKnowledge Baseを更新します。

```mermaid
sequenceDiagram
    participant ES as EventBridge Scheduler
    participant L3 as Lambda<br/>(Issue Extractor)
    participant SM as Secrets Manager
    participant GH as GitHub
    participant S3 as S3<br/>(Issue History)
    participant KB as Bedrock Knowledge Base

    ES->>L3: 日次トリガー
    L3->>SM: PAT取得要求
    SM->>L3: PAT返却
    L3->>GH: Issue履歴取得
    GH->>L3: Issue履歴データ
    L3->>S3: データ保存
    S3->>L3: 保存完了
    L3->>KB: データ同期開始
    KB->>L3: 同期完了
```

#### 出力

Lambda実行結果：

```json
// 実行結果
{
  "statusCode": 200,
  "body": {
    "processed_issues": 15,
    "s3_files": ["保存されたファイルパス"],
    "knowledge_base_sync": {
      "ingestion_job_id": "取り込みジョブ ID",
      "status": "STARTING"
    },
    "execution_time": "実行時間（秒）"
  }
}
```

#### 保存データ形式

##### ファイル名形式

```
{repository}/{issue_number}_{closed_date}.md
```

##### Frontmatter Markdown形式

```markdown
---
issue_number: 123
title: "Issue タイトル"
state: "closed"
created_at: "2024-01-01T00:00:00Z"
closed_at: "2024-01-02T00:00:00Z"
assignee: "担当者名"
labels: ["bug", "priority-high"]
repository: "owner/repo-name"
url: "GitHub Issue URL"
---

# Issue本文

（GitHub IssueのBodyをそのまま記載）

## コメント履歴

### ユーザー名 (2024-01-01 12:00)
（コメント内容）

### ユーザー名 (2024-01-02 09:00)
（コメント内容）
```

## 設定詳細

### Bedrock Agent設定

- **Name**: `"dev-issue-creation-agent"`
- **Foundation Model**: `"anthropic.claude-v2"`
- **Instructions**: `"GitHub Issueの作成を支援するエージェント。過去のIssue履歴を参考に適切なタイトル、本文、ラベルを生成し、ユーザーとの対話を通じて内容を精査します。"`
- **Session TTL**: `3600秒`

**Action Group**:

- **Name**: `"issue-creator"`
- **Lambda Function**: issue_creator Lambda関数のARN
- **OpenAPI Schema**: 必須パラメータ `repository, title, body`、オプション `labels`

### Knowledge Base設定

- **Name**: `"dev-issue-history-knowledge-base"`
- **Embedding Model**: `"amazon.titan-embed-text-v2:0"`
- **Vector Store**: OpenSearch Serverless
- **Collection**: `"dev-bedrock-knowledge-base"`
- **Chunking**: Fixed Size 300トークン、20%オーバーラップ
- **Data Source**: S3バケット、`*.md`ファイルのみ

### セッション管理設定

SlackイベントのメタデータからSessionIDを決定論的に生成し、同一スレッド内では同じSessionIDを継続使用します。

- **Session ID Format**: `"{user_id}_{channel_id}_{root_timestamp}"`
- **制限**: 100文字以内、`[0-9a-zA-Z._:-]+`パターン
- **スレッド対応**: 同一スレッド内は同一SessionID

#### SessionID生成ロジック

スレッド返信時は`thread_ts`を、新規メンション時は`message_ts`をルートタイムスタンプとして使用し、`{user_id}_{channel_id}_{root_timestamp}`形式でSessionIDを生成します。

### Issue履歴抽出の定期実行設定

- **Name**: `"dev-issue-extractor-daily-schedule"`
- **Schedule**: `"cron(0 16 * * ? *)"`
- **Target**: issue_extractor Lambda関数
- **Input**: `{"target_date": "previous_day"}`
- **Retry**: 3回、1時間以内
