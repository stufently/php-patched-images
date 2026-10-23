# syntax=docker/dockerfile:1.7
#
# Profile layers on top of a "core" PHP image built from core/<branch>/<os>/<variant>/
# (vendored docker-library/php Dockerfiles with the patched PHP_VERSION, or the
# hand-maintained core/*-backport/ ones).
#
#   docker build -t local/php-core:8.5-fpm core/8.5/trixie/fpm
#   docker build --build-arg BASE_IMAGE=local/php-core:8.5-fpm --target app -t my/php:8.5-fpm-app .
#
# Targets: base | web | app | dev

ARG BASE_IMAGE=php-core
ARG COMPOSER_IMAGE=composer:2.10.3@sha256:af98f42dfff7c68ba8d53c2164fd9fde1087b7d449514baa38c418b1f6bc4bac

FROM ${COMPOSER_IMAGE} AS composer

# ---------------------------------------------------------------- base
FROM ${BASE_IMAGE} AS base

# Pull current OS security updates (Debian or Alpine) on every (weekly) rebuild.
RUN set -eux; \
    if command -v apk >/dev/null; then \
      apk upgrade --no-cache; \
    else \
      apt-get update; \
      apt-get -y upgrade; \
      rm -rf /var/lib/apt/lists/*; \
    fi

# mlocati/docker-php-extension-installer, pinned release + checksum
ADD --chmod=0755 \
    --checksum=sha256:9c26dd516b8147235c4e924c52e2f076fb2b3f278f5457e88918518ebfee9e01 \
    https://github.com/mlocati/docker-php-extension-installer/releases/download/2.12.3/install-php-extensions \
    /usr/local/bin/install-php-extensions

# pecl.php.net is flaky under load: retry the whole install a few times
RUN set -eux; \
    printf '%s\n' '#!/bin/sh' \
      'for i in 1 2 3 4; do install-php-extensions "$@" && exit 0; echo "retry $i" >&2; sleep $((i * 15)); done' \
      'exit 1' > /usr/local/bin/ipe-retry; \
    chmod 0755 /usr/local/bin/ipe-retry

# profile extension installer (memcached build deps, PHP 7.4 specifics)
COPY --chmod=0755 profile/ipe-profile /usr/local/bin/ipe-profile

# opcache is built into PHP 8.5; on 8.2-8.4 it is a shared ext that must be enabled
RUN set -eux; \
    if ! php -m | grep -qi '^Zend OPcache$'; then docker-php-ext-enable opcache; fi; \
    cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; \
    { \
      echo 'expose_php = Off'; \
      echo 'opcache.enable = 1'; \
      echo 'opcache.enable_cli = 0'; \
      echo '; php.net advisory 2026-10-23-1 (CVE-2026-115560): off by default,'; \
      echo '; override in your own conf.d if you need session upload progress.'; \
      echo 'session.upload_progress.enabled = 0'; \
    } > "$PHP_INI_DIR/conf.d/zz-patched-images.ini"; \
    php -v

LABEL org.opencontainers.image.source="https://github.com/stufently/php-patched-images" \
      org.opencontainers.image.description="PHP built from source with fixes for CVE-2026-109618 / CVE-2026-109619 (7.4/8.1: best-effort backport builds)" \
      org.opencontainers.image.licenses="MIT"

# ---------------------------------------------------------------- web
# WordPress / OpenCart / Joomla / Drupal / classic CMS
FROM base AS web
RUN set -eux; \
    ipe-profile \
      bcmath exif gd intl ldap mysqli pdo_mysql soap zip \
      imagick-3.8.1 memcached-3.4.0; \
    php -m

# ---------------------------------------------------------------- app
# Laravel / Symfony / generic framework apps, queue workers (cli)
FROM base AS app
RUN set -eux; \
    ipe-profile \
      bcmath exif gd intl ldap pcntl pdo_mysql pdo_pgsql pgsql soap sockets zip \
      redis-6.3.0 apcu-5.1.28 memcached-3.4.0; \
    php -m
COPY --from=composer /usr/bin/composer /usr/local/bin/composer

# ---------------------------------------------------------------- dev
# app + Xdebug + development php.ini. NOT for production.
# Xdebug 3.2+ needs PHP 8.0+: the 7.4 backport gets 3.1.6, the last release
# for PHP 7.2-8.1 (see README).
FROM app AS dev
RUN set -eux; \
    case "$PHP_VERSION" in \
      7.4.*) xdebug=xdebug-3.1.6 ;; \
      *)     xdebug=xdebug-3.5.3 ;; \
    esac; \
    ipe-profile "$xdebug"; \
    cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"; \
    { \
      echo 'xdebug.mode = develop,debug'; \
      echo 'xdebug.client_host = host.docker.internal'; \
      echo 'xdebug.start_with_request = trigger'; \
    } > "$PHP_INI_DIR/conf.d/zz-xdebug.ini"; \
    php -m
