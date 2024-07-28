# クライアントビルド用ステージ
FROM node:21.5.0 AS client-build

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

# Composer をインストール
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 必要なツールをインストール
RUN echo "deb http://ftp.de.debian.org/debian/ bookworm main" > /etc/apt/sources.list \
  && echo "deb http://security.debian.org/ bookworm-security main" >> /etc/apt/sources.list \
  && apt-get update \
  && apt-get install -y \
  zip \
  unzip \
  git

# サーバーの依存関係をインストール
COPY server/composer.json server/composer.lock ./
RUN COMPOSER_ALLOW_SUPERUSER=1 composer clear-cache && COMPOSER_ALLOW_SUPERUSER=1 composer install --no-interaction --prefer-dist --optimize-autoloader

# サーバーのソースコードをコピー
COPY server/ ./

# Apache の設定ファイルをコピー
COPY httpd.conf /etc/apache2/apache2.conf

# 最終ステージ
FROM php:8.2-apache

WORKDIR /var/www/html

# 必要な PHP 拡張とユーティリティをインストール
RUN echo "deb http://ftp.de.debian.org/debian/ bookworm main" > /etc/apt/sources.list \
  && echo "deb http://security.debian.org/ bookworm-security main" >> /etc/apt/sources.list \
  && apt-get update \
  && apt-get install -y \
  libzip-dev \
  unzip \
  git \
  && docker-php-ext-install zip pdo pdo_mysql

# クライアントのビルド成果物をコピー
COPY --from=client-build /app/client/.next /var/www/html/client

# サーバーのソースコードをコピー
COPY --from=server-build /app/server /var/www/html

# Apache の設定ファイルをコピー
COPY httpd.conf /etc/apache2/apache2.conf

# パーミッションの設定（必要に応じて）
RUN chown -R www-data:www-data /var/www/html

# ポート設定
EXPOSE 80

# Apache を起動するためのコマンド
CMD ["apache2-foreground"]
