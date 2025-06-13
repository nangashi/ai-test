# Dev Container用のベースイメージを使用
FROM mcr.microsoft.com/devcontainers/base:ubuntu

# 基本パッケージのアップデートとインストール
# RUN apt-get update && apt-get install -y \
#     curl \
#     && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリを設定
WORKDIR /workspace

USER vscode

# Aquaのインストール
RUN curl -sSfL https://raw.githubusercontent.com/aquaproj/aqua-installer/v3.1.2/aqua-installer | bash && \
  echo 'export PATH="/home/vscode/.local/share/aquaproj-aqua/bin:$PATH"' >> ~/.bashrc
COPY aqua.yaml /tmp/
RUN cd /tmp && \
  /home/vscode/.local/share/aquaproj-aqua/bin/aqua i -a

# 権限エラー対策のためにディレクトリを事前作成
RUN mkdir -p \
  /home/vscode/.vscode-server \
  /home/vscode/.cursor-server \
  /home/vscode/.claude
