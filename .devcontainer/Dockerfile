# Dev Container用のベースイメージを使用
FROM mcr.microsoft.com/devcontainers/base:ubuntu

# 基本パッケージのアップデートとインストール
# RUN apt-get update && apt-get install -y \
#     curl \
#     && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリを設定
WORKDIR /workspace

# dockerグループを追加し、vscodeユーザーをそのグループに追加
# ホストのdockerグループのGIDを取得して設定
ARG DOCKER_GID=1001
RUN groupadd -g ${DOCKER_GID} docker && \
  usermod -aG docker vscode

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
