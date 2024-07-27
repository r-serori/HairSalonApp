# クライアントビルド用ステージ
FROM node:18 AS client-build

WORKDIR /app/client

# クライアントの依存関係をインストール
COPY client/package*.json ./
RUN npm install

# クライアントのソースコードをコピー
COPY client/ ./

# アプリケーションをビルド
RUN npm run build

# サーバービルド用ステージ
FROM php:8.2-apache AS server-build

WORKDIR /app/server

# 必要な PHP 拡張とユーティリティをインストール
RUN apt-get update && apt-get install -y \
  libzip-dev \
  unzip \
  git \
  && docker-php-ext-install zip pdo pdo_mysql

# Composer をインストール
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# サーバーの依存関係をインストール
COPY server/composer.json server/composer.lock ./
RUN composer clear-cache && composer install --no-interaction --prefer-dist --optimize-autoloader

# サーバーのソースコードをコピー
COPY server/ ./

# パーミッションの設定（必要に応じて）
RUN chown -R www-data:www-data /app/server

# 最終ステージ：クライアントとサーバーのアプリケーションを Nginx で提供
FROM nginx:latest

# クライアントのビルド成果物をコピー
COPY --from=client-build /app/client/.next /usr/share/nginx/html/client

# サーバーのビルド成果物をコピー
COPY --from=server-build /app/server /usr/share/nginx/html/server

# ポート設定
EXPOSE 80

# Nginx のデフォルトコマンドを使用
CMD ["nginx", "-g", "daemon off;"]
