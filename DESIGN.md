# システム設計

## 概要

AWS Bedrockを活用したSlackベースのIssue起票システムです。ユーザーがSlackでメンションすることで、AIが適切なIssueを自動生成します。

## 特徴

- AWS上に構築されたシステム
- Slackでメンションして依頼することでGitHub Issueの作成が可能
- 依頼すると文案を提示し、指示するとIssueを作成する
- 対話により文案の修正が可能（Bedrock Agentのセッション管理機能を活用）
- クローズ済みIssueを日次で収集し、Issue作成時の参考にする

## 処理フロー

```mermaid
graph TD
    A((User)) -->|request| B[Slack]
    B -->|Events API| C["Lambda<br/>(AI Interface)"]
    C -->|query| D{Bedrock Agent}
    D --> E[("Bedrock Knowledge Base<br/>(Issue/Team Knowledge)")]
    E --> D
    D -->|action call| I["Lambda<br/>(Issue Creator)"]
    I -->|create issue| F[GitHub]
    D -->|response| C
    C -->|response| B
    B -->|created issue info| A

    H[EventBridge Scheduler] -->|daily trigger| G["Lambda<br/>(Issue Extractor)"]
    F --> G
    G -->|put| J["S3<br/>(Issue History)"]
    G -->|StartIngestionJob| E
```

## 処理シーケンス

### Issue作成

#### 処理概要

- ユーザーがSlackでBotにメンションしてIssue作成を依頼
- SlackのEvents APIからLambda Function URL経由でLambda（AI Interface）にイベント送信
- LambdaがBedrock Agentにクエリを送信してIssue内容の生成を依頼
- Bedrock AgentがKnowledge Baseから過去のIssue履歴や関連情報を検索
- 検索結果を基にBedrock AgentがIssue作成内容（タイトル、本文、ラベル等）を生成
- 生成されたIssue内容をSlackに返信してユーザーに確認を求める
- ユーザーが修正依頼をした場合、同一SessionIDで対話を継続し内容を修正
- 最終承認後、Bedrock AgentがアクションでLambda（Issue Creator）を呼び出し
- Lambda（Issue Creator）がGitHub APIを使用してIssueを作成
- 作成完了とIssue URLをSlackに通知

#### シーケンス図

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

    Note over BA: SessionID生成
    
    U->>S: mention/request
    S->>L1: event (Function URL)
    L1->>BA: query (sessionId)
    BA->>KB: search knowledge
    KB->>BA: knowledge data
    BA->>L1: generated issue content
    L1->>S: issue preview
    S->>U: issue preview
    
    alt 修正依頼の場合
        U->>S: modification request
        S->>L1: modification event
        L1->>BA: modify request (same sessionId)
        Note over BA: 会話履歴保持
        BA->>L1: modified issue content
        L1->>S: updated preview
        S->>U: updated preview
    end
    
    U->>S: final approval
    S->>L1: approval event
    L1->>BA: create issue request (same sessionId)
    BA->>L2: action call (issue data)
    L2->>SM: request
    SM->>L2: PAT
    L2->>GH: create issue
    GH->>L2: issue created (with URL)
    L2->>BA: issue created response
    BA->>L1: response
    L1->>S: success notification with URL
    S->>U: created issue info with URL
```

### Issue履歴抽出

#### 処理概要

- EventBridge Schedulerが日次でLambda（Issue Extractor）を起動
- LambdaがSecrets ManagerからGitHub Personal Access Token（PAT）を取得
- 取得したPATを使用してGitHub APIから**前日にクローズしたIssue**の履歴データを取得
  - GitHub API: `GET /repos/{owner}/{repo}/issues?state=closed&closed:YYYY-MM-DD..YYYY-MM-DD`
- 取得したIssue履歴をFrontmatter Markdown形式でS3バケットに保存
- Bedrock Knowledge BaseのStartIngestionJob APIを実行してS3データを同期
- Knowledge Baseが新しいIssue履歴データを学習データとして利用可能になる

#### シーケンス図

```mermaid
sequenceDiagram
    participant ES as EventBridge Scheduler
    participant L2 as Lambda<br/>(Issue Extractor)
    participant SM as Secrets Manager
    participant GH as GitHub
    participant S3 as S3<br/>(Issue History)
    participant KB as Bedrock Knowledge Base

    ES->>L2: daily trigger
    L2->>SM: request
    SM->>L2: PAT
    L2->>GH: request
    GH->>L2: issue history
    L2->>S3: put
    S3->>L2: response
    L2->>KB: StartIngestionJob API
    KB->>L2: sync complete
```

#### 保存データ形式

##### ファイル名形式

```
{repository}/{issue_number}_{closed_date}.md
```

例: `my-project/123_2024-01-15.md`

##### Frontmatter Markdown形式

```markdown
---
issue_number: 123
title: "バグ修正: ログイン機能のエラーハンドリング"
state: closed
created_at: 2024-01-10T09:00:00Z
closed_at: 2024-01-15T17:30:00Z
assignee: "yamada-taro"
labels: ["bug", "frontend", "high-priority"]
repository: "my-project"
url: "https://github.com/org/my-project/issues/123"
---

# Issue概要

ログイン画面でパスワードを間違えた際のエラーメッセージが表示されない問題を修正しました。

## 問題内容

- パスワード入力エラー時にエラーメッセージが表示されない
- ユーザーがエラーの原因を特定できない

## 解決方法

1. エラーハンドリングロジックの修正
2. UI側でのエラーメッセージ表示機能の実装
3. 適切なエラーメッセージテキストの追加

## 影響範囲

- ログイン機能全般
- エラーハンドリング機能

## テスト内容

- 正常ログインのテスト
- 異常系（パスワード間違い）のテスト
- エラーメッセージ表示のテスト
```

## コンポーネント詳細

### フロントエンド

- **Slack**: ユーザーインターフェース、メンション受付

### アプリケーションレイヤー

- **Lambda (AI Interface)**: Function URL有効、Slackイベント処理、Bedrock連携、レスポンス生成
- **Lambda (Issue Creator)**: GitHub Issue作成、PAT管理

### AI レイヤー

- **Bedrock Agent**: AIエージェント、自然言語処理、セッション管理による対話機能
- **Bedrock Knowledge Base**: ナレッジベース、情報検索

### ストレージレイヤー

- **S3**: Issue履歴データ保存（Frontmatter Markdown形式）
- **Secrets Manager**: GitHub Personal Access Token管理

### スケジューラ

- **EventBridge Scheduler**: 日次Issue履歴抽出トリガー

