FROM fabiodcorreia/base-php:1.0.1

ARG VERSION
ENV WALLABAG_VERSION=2.3.8
LABEL build_version="version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="fabiodcorreia"

ENV WALLABAG_VERSION=2.3.8
ENV WALLABAG_PATH=/var/www/html

WORKDIR ${WALLABAG_PATH}

RUN apk add --no-cache \
  composer \
  libwebp \
  php7-bcmath \
  php7-ctype \
  php7-curl \
  php7-dom \
  php7-fpm \
  php7-gd \
  php7-gettext \
  php7-iconv \
  php7-pdo_mysql \
  php7-phar \
  php7-tokenizer \
  php7-zlib \
  php7-sockets \
  php7-xmlreader \
  php7-tidy \
  php7-intl

ADD https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh /usr/bin

RUN \
  echo "**** download application ****" && \
    curl -LJO \
      "https://github.com/wallabag/wallabag/releases/download/${WALLABAG_VERSION}/wallabag-release-${WALLABAG_VERSION}.tar.gz"  && \
  echo "**** extrat package ****" && \
    tar -zxvf "wallabag-release-${WALLABAG_VERSION}.tar.gz" --strip-components 1 && \
  echo "**** clean package package ****" && \
    rm "wallabag-release-${WALLABAG_VERSION}.tar.gz" && \
  echo "**** composer install ****" && \
    SYMFONY_ENV=prod composer install --no-dev -o --prefer-dist --no-progress && \
  echo "**** clean ****" &&\
    rm -rf /var/cache/apk/* && \
  echo "**** make wait-for-it.sh executable ****" && \
    chmod +x /usr/bin/wait-for-it.sh && \
  echo "**** clean non necessary files ****" && \
    rm -fr docker docker-compose.yml tests .github .travis.yml .zappr.yaml


# Copy local files
COPY root/ /

# Ports and Volumes
VOLUME /config
