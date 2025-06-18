# Python開発ガイド

このガイドでは、本プロジェクトでのPython開発における標準的な構成、手順、ガイドラインを説明します。

## アプリケーション構造

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

## 初期構築

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

# 6. .gitignore設定
# Python必要最低限の除外設定
cat > .gitignore << 'EOF'
# Python
__pycache__/
.venv/

# Development tools
.pytest_cache/
.mypy_cache/
.ruff_cache/

# Lambda deployment
*.zip
EOF

# 7. Lambdaデプロイ設定の作成（Lambdaアプリの場合）
# lambroll/function.jsonをDESIGN.mdのデプロイ先仕様に合わせて作成
```

この初期構築完了後、DESIGN.mdの入出力仕様に従ってsrc/main.pyの実装を開始する。

## 実装指針

- **入出力仕様**: DESIGN.mdのアプリケーション一覧の入力・出力セクションに準拠
- **デプロイ設定**: DESIGN.mdのデプロイ先情報をlambroll/function.jsonに反映
- **テスト設計**: DESIGN.mdの処理フローを基に結合テストシナリオを作成

## 環境セットアップ

```bash
cd apps/<アプリ名>
uv venv                    # 仮想環境作成
source .venv/bin/activate  # 仮想環境有効化
uv sync                    # 依存関係インストール
```

## コマンド

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

## 技術スタック

Python開発の標準ツール：

- **uv**: パッケージ管理
- **ruff**: フォーマット・リント
- **mypy**: 型チェック
- **pytest**: テスト
- **lambroll**: Lambdaデプロイ

## 実装ガイドライン

### コード構成・可読性

- **1ファイル1クラス**: ファイルごとに一つのクラスを定義し、責務を明確化
- **クラス責務の明示**: ファイルの先頭にクラスの責務をコメントで記載
- **単一責任の原則**: 同じクラスに複数の責務がある場合はクラスを分割
- **メソッドの説明**: 各メソッドには処理内容を説明する日本語の一行コメントを付与
- **処理目的の明示**: 複雑あるいは直感的に理解しにくい処理では目的や背景をコメントで記載

### コード品質・保守性

- **型ヒント必須**: Python型ヒントを付与して型安全性を確保
- **ruffフォーマット**: `uv run ruff format`による自動フォーマット適用
- **ruffリント**: `uv run ruff check`によるリント実行
- **型チェック**: `uv run mypy src`による静的型チェック実行

## テスト方針

### テスト実装方針

- **1テストメソッド1アサーション**: 単一の観点のみをテストし、失敗原因を明確化
- **Given-When-Then構造**: テストケースを3段階で構造化（準備・実行・検証）
- **テスト名**: `test_<対象メソッド名>_<前提条件>_<期待結果>`形式で命名
- **日本語コメント**: テストの意図・背景を明記
- **フィクスチャ活用**: pytest.fixtureでテストデータ・モックオブジェクトを共通化

## デプロイ（Lambda関数）

### lambrollを使用したデプロイ

**設定ファイル**: `function.json`でLambda関数の設定を管理

### デプロイワークフロー

1. **コード品質チェック**: ruff format/check、mypy実行
2. **テスト実行**: pytestでユニット・結合テスト
3. **デプロイパッケージ作成**: Lambda用zipパッケージの生成
   - `uv export --no-dev --format requirements-txt > requirements.txt`
   - `mkdir lambda_package`
   - `pip install -r requirements.txt --target lambda_package --quiet`
   - `cp src/*.py lambda_package/`
   - `cd lambda_package && zip -r ../deployment.zip . -x "*.pyc" "*/__pycache__/*"`
4. **デプロイ準備**: lambroll deploy --dry-runで確認
5. **デプロイ実行**: lambroll deploy --src deployment.zipで本番反映
6. **動作確認**: lambroll logsでログ確認

### lambrollコマンド

```bash
# デプロイ
lambroll deploy --src deployment.zip    # zipファイル指定でデプロイ
lambroll deploy --dry-run               # デプロイ内容の確認

# 管理
lambroll rollback                       # 前のバージョンにロールバック
lambroll delete                         # Lambda関数を削除
lambroll delete --dry-run               # 削除内容の確認

# 監視
lambroll logs                           # 最新のログを表示
lambroll logs --follow                  # ログをリアルタイム監視
```

## 参考情報

- **設計書**: [DESIGN.md](../../DESIGN.md)