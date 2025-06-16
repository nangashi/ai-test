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

    GH -->|Issue履歴| INF[Issueナレッジ機能]
    INF -->|ナレッジ蓄積| IC
```

## アーキテクチャ

<details>
<summary>システム全体アーキテクチャ図</summary>

```mermaid
graph TB
    U((User))
    S[Slack]
    GH[GitHub]

    subgraph "Issue作成機能"
        SH["Lambda<br/>(Slackハンドラー)"]
        IG["Lambda<br/>(Issue生成ツール)"]
        BA{Bedrock Agent}
    end

    subgraph "Issueナレッジ機能"
        ES[EventBridge Scheduler]
        KB_TOOL["Lambda<br/>(ナレッジ構築ツール)"]
        S3[S3]
    end

    subgraph "共有リソース"
        KB[("Knowledge Base")]
        SM[Secrets Manager]
    end

    U -->|Issue作成依頼| S
    S -->|イベントコール| SH
    SH -->|クエリ| BA
    BA -->|アクション| IG
    IG -->|Issue作成| GH
    BA -->|Issue提案| SH
    SH -->|Issue提案| S
    S -->|Issue提案| U

    ES -->|日次トリガー| KB_TOOL
    KB_TOOL -->|Issue履歴| GH
    KB_TOOL -->|データ保存| S3

    BA <-->|Issue履歴参照| KB
    S3 -->|ナレッジ蓄積| KB

    IG -->|PAT取得| SM
    KB_TOOL -->|PAT取得| SM
```

</details>

## 機能シーケンス

### Issue作成機能

<details>
<summary>Issue作成機能シーケンス図</summary>

```mermaid
sequenceDiagram
    participant U as User
    participant S as Slack

    box navy Issue作成機能
        participant SH as Lambda<br/>(Slackハンドラー)
        participant BA as Bedrock Agent
        participant IG as Lambda<br/>(Issue生成ツール)
    end

    participant KB as Knowledge Base
    participant GH as GitHub

    U->>S: Issue作成依頼
    S->>SH: イベントコール
    SH->>BA: クエリ送信
    BA->>KB: Issue履歴参照
    KB->>BA: 関連データ
    BA->>SH: Issue内容生成
    SH->>S: Issue提案
    S->>U: Issue提案

    alt 修正依頼の場合
        U->>S: 修正指示
        S->>SH: 修正イベントコール
        SH->>BA: 修正リクエスト
        BA->>SH: 修正されたIssue内容
        SH->>S: 修正Issue提案
        S->>U: 修正Issue提案
    end

    U->>S: 最終承認
    S->>SH: 承認イベントコール
    SH->>BA: Issue作成リクエスト
    BA->>IG: アクション実行
    IG->>GH: Issue作成
    GH->>IG: 作成完了
    IG->>BA: 作成完了応答
    BA->>SH: 応答
    SH->>S: 完了通知
    S->>U: 作成完了情報
```

</details>

### Issueナレッジ機能

<details>
<summary>Issueナレッジ機能シーケンス図</summary>

```mermaid
sequenceDiagram
    participant ES as EventBridge Scheduler

    box darkgreen Issueナレッジ機能
        participant KBT as Lambda<br/>(ナレッジ構築ツール)
        participant S3 as S3
    end

    participant GH as GitHub
    participant KB as Knowledge Base

    ES->>KBT: 日次トリガー
    KBT->>GH: Issue履歴
    GH->>KBT: Issue履歴データ
    KBT->>KBT: データ処理・構造化
    KBT->>S3: データ保存
    S3->>KBT: 保存完了
    S3->>KB: ナレッジ蓄積
    KB->>KBT: 蓄積完了
```

</details>

## アプリケーション設計

### Issue生成ツール (issue_generator)

#### 概要

Bedrock Agentからのアクション呼び出しで起動し、GitHub Issueを作成するLambda関数

#### 入力

<details>
<summary>Bedrock Agentからの入力JSONスキーマ</summary>

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

</details>

#### 処理

Bedrock Agentからのアクション呼び出しを受けて、Secrets ManagerからGitHub PATを取得し、GitHub API経由でIssueを作成して結果を返却します。

<details>
<summary>Issue生成ツール処理シーケンス図</summary>

```mermaid
sequenceDiagram
    participant BA as Bedrock Agent
    participant L2 as Lambda<br/>(Issue生成ツール)
    participant SM as Secrets Manager
    participant GH as GitHub

    BA->>L2: アクション実行 (issue data)
    L2->>SM: PAT取得要求
    SM->>L2: PAT返却
    L2->>GH: Issue作成
    GH->>L2: Issue作成完了 (URL付き)
    L2->>BA: 作成完了応答
```

</details>

#### 出力

<details>
<summary>Bedrock Agentへのレスポンス</summary>

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
```

</details>

### Slackハンドラー (slack_handler)

#### 概要

Slackのapp_mentionイベントで起動し、Bedrock Agentとやり取りしてSlackに応答するLambda関数

#### 入力

<details>
<summary>Slack Events APIからのapp_mentionイベント</summary>

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

</details>

#### 処理

Slack Events APIからのapp_mentionイベントを受信し、SessionIDを生成してBedrock Agentとやり取りを行い、応答をSlackに転送します。

<details>
<summary>Slackハンドラー処理シーケンス図</summary>

```mermaid
sequenceDiagram
    participant U as User
    participant S as Slack
    participant L1 as Lambda<br/>(Slackハンドラー)
    participant BA as Bedrock Agent

    U->>S: メンション/依頼
    S->>L1: イベント送信 (Function URL)
    Note over L1: SessionID生成
    L1->>BA: クエリ送信 (sessionId)
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
    BA->>L1: 作成完了応答
    L1->>S: 成功通知 (Issue URL付き)
    S->>U: 作成完了情報 (Issue URL付き)
```

</details>

#### 出力

<details>
<summary>Slackへの応答とメッセージ投稿</summary>

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

</details>

### ナレッジ構築ツール (knowledge_builder)

#### 概要

EventBridge Schedulerの日次スケジュールで起動し、GitHub Issue履歴を収集してS3保存・Knowledge Base更新するLambda関数

#### 入力

<details>
<summary>EventBridge Schedulerからの定期実行入力</summary>

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

</details>

#### 処理

EventBridge Schedulerからの日次実行により、前日クローズのIssue履歴をGitHub APIから取得し、Frontmatter Markdown形式でS3に保存してKnowledge Baseを更新します。

<details>
<summary>ナレッジ構築ツール処理シーケンス図</summary>

```mermaid
sequenceDiagram
    participant ES as EventBridge Scheduler
    participant L3 as Lambda<br/>(ナレッジ構築ツール)
    participant SM as Secrets Manager
    participant GH as GitHub
    participant S3 as S3<br/>(Issue History)
    participant KB as Bedrock Knowledge Base

    ES->>L3: 日次トリガー
    L3->>SM: PAT取得要求
    SM->>L3: PAT返却
    L3->>GH: Issue履歴
    GH->>L3: Issue履歴データ
    L3->>S3: データ保存
    S3->>L3: 保存完了
    L3->>KB: データ同期開始
    KB->>L3: 同期完了
```

</details>

#### 出力

<details>
<summary>Lambda実行結果</summary>

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

</details>

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
- **Lambda Function**: issue_generator Lambda関数のARN
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
- **Target**: knowledge_builder Lambda関数
- **Input**: `{"target_date": "previous_day"}`
- **Retry**: 3回、1時間以内
