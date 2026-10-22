#
# PHP 7.4 built from the php-src security backport branch
#   PHP-7.4-CVE-2026-109618-109619
# pinned to commit 712e60f9edfd03f0960fc4fc3c2c375f42b90aa2.
#
# BEST-EFFORT build, NOT an official PHP release: PHP 7.4 is end-of-life and the
# PHP project publishes only this minimal source backport for CVE-2026-109618 /
# CVE-2026-109619. Derived from docker-library/php 8.1/bookworm (MIT), with the
# release tarball download replaced by a git checkout of the pinned commit.
# Maintained by hand: scripts/sync-upstream.sh does not touch this file.
#

FROM debian:bookworm-slim@sha256:7ff6ba31527b9e336162fa061746c366c4b2032f4d2cff2078bea43f78efe3f8

# prevent Debian's PHP packages from being installed
# https://github.com/docker-library/php/pull/542
RUN set -eux; \
	{ \
		echo 'Package: php*'; \
		echo 'Pin: release *'; \
		echo 'Pin-Priority: -1'; \
	} > /etc/apt/preferences.d/no-debian-php

# dependencies required for running "phpize"
# (see persistent deps below)
ENV PHPIZE_DEPS \
		autoconf \
		dpkg-dev \
		file \
		g++ \
		gcc \
		libc-dev \
		make \
		pkg-config \
		re2c

# persistent / runtime deps
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		$PHPIZE_DEPS \
		ca-certificates \
		curl \
		xz-utils \
	; \
	rm -rf /var/lib/apt/lists/*

ENV PHP_INI_DIR /usr/local/etc/php
RUN set -eux; \
	mkdir -p "$PHP_INI_DIR/conf.d"; \
# allow running as an arbitrary user (https://github.com/docker-library/php/issues/743)
	[ ! -d /var/www/html ]; \
	mkdir -p /var/www/html; \
	chown www-data:www-data /var/www/html; \
	chmod 1777 /var/www/html

ENV APACHE_CONFDIR /etc/apache2
ENV APACHE_ENVVARS $APACHE_CONFDIR/envvars

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends apache2; \
	rm -rf /var/lib/apt/lists/*; \
	\
# generically convert lines like
#   export APACHE_RUN_USER=www-data
# into
#   : ${APACHE_RUN_USER:=www-data}
#   export APACHE_RUN_USER
# so that they can be overridden at runtime ("-e APACHE_RUN_USER=...")
	sed -ri 's/^export ([^=]+)=(.*)$/: ${\1:=\2}\nexport \1/' "$APACHE_ENVVARS"; \
	\
# setup directories and permissions
	. "$APACHE_ENVVARS"; \
	for dir in \
		"$APACHE_LOCK_DIR" \
		"$APACHE_RUN_DIR" \
		"$APACHE_LOG_DIR" \
# https://salsa.debian.org/apache-team/apache2/-/commit/b97ca8714890ead1ba6c095699dde752e8433205
		"$APACHE_RUN_DIR/socks" \
	; do \
		rm -rvf "$dir"; \
		mkdir -p "$dir"; \
		chown "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$dir"; \
# allow running as an arbitrary user (https://github.com/docker-library/php/issues/743)
		chmod 1777 "$dir"; \
	done; \
	\
# delete the "index.html" that installing Apache drops in here
	rm -rvf /var/www/html/*; \
	\
# logs should go to stdout / stderr
	ln -sfT /dev/stderr "$APACHE_LOG_DIR/error.log"; \
	ln -sfT /dev/stdout "$APACHE_LOG_DIR/access.log"; \
	ln -sfT /dev/stdout "$APACHE_LOG_DIR/other_vhosts_access.log"; \
	chown -R --no-dereference "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$APACHE_LOG_DIR"

# Apache + PHP requires preforking Apache for best results
RUN a2dismod mpm_event && a2enmod mpm_prefork

# PHP files should be handled by PHP, and should be preferred over any other file type
RUN { \
		echo '<FilesMatch \.php$>'; \
		echo '\tSetHandler application/x-httpd-php'; \
		echo '</FilesMatch>'; \
		echo; \
		echo 'DirectoryIndex disabled'; \
		echo 'DirectoryIndex index.php index.html'; \
		echo; \
		echo '<Directory /var/www/>'; \
		echo '\tOptions -Indexes'; \
		echo '\tAllowOverride All'; \
		echo '</Directory>'; \
	} | tee "$APACHE_CONFDIR/conf-available/docker-php.conf" \
	&& a2enconf docker-php

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# https://github.com/docker-library/php/issues/272
# -D_LARGEFILE_SOURCE and -D_FILE_OFFSET_BITS=64 (https://www.php.net/manual/en/intro.filesystem.php)
ENV PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
ENV PHP_CPPFLAGS="$PHP_CFLAGS"
ENV PHP_LDFLAGS="-Wl,-O1 -pie"

# PHP 7.4 does not build against OpenSSL 3 (ext/openssl needs 1.0.2-1.1.1).
# OpenSSL 1.1.1w (last 1.1.1 release, EOL) is built into its own prefix with
# an rpath, so only PHP's openssl extension uses it; everything else in the
# image (curl, apache, Debian packages) keeps using Debian's OpenSSL 3.
ENV OPENSSL11_VERSION=1.1.1w \
	OPENSSL11_PREFIX=/usr/local/openssl-1.1
ENV OPENSSL11_URL="https://github.com/openssl/openssl/releases/download/OpenSSL_1_1_1w/openssl-1.1.1w.tar.gz" \
	OPENSSL11_SHA256="cf3098950cb4d853ad95c0841f1f9c6d3dc102dccfcacd521d93925208b76ac8" \
	OPENSSL11_GPG_KEY="EFC0A467D613CB83C7ED6D30D894E2CE8B3D79F5"

RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends gnupg perl; \
	rm -rf /var/lib/apt/lists/*; \
	\
	mkdir -p /usr/src/openssl; \
	cd /usr/src; \
	curl -fsSL -o openssl.tar.gz "$OPENSSL11_URL"; \
	echo "$OPENSSL11_SHA256 *openssl.tar.gz" | sha256sum -c -; \
	curl -fsSL -o openssl.tar.gz.asc "$OPENSSL11_URL.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$OPENSSL11_GPG_KEY"; \
	gpg --batch --verify openssl.tar.gz.asc openssl.tar.gz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" || { sleep 1; rm -rf "$GNUPGHOME"; }; \
	tar -xzf openssl.tar.gz -C openssl --strip-components=1; \
	cd openssl; \
	./config \
		--prefix="$OPENSSL11_PREFIX" \
		--openssldir="$OPENSSL11_PREFIX/ssl" \
		--libdir=lib \
		shared no-ssl3 no-weak-ssl-ciphers no-tests \
		"-Wl,-rpath,$OPENSSL11_PREFIX/lib" \
	; \
	make -j "$(nproc)"; \
	make install_sw install_ssldirs; \
	rm -f "$OPENSSL11_PREFIX"/lib/*.a; \
# use Debian's CA store (ca-certificates) instead of an empty certs dir
	rm -rf "$OPENSSL11_PREFIX/ssl/certs"; \
	ln -s /etc/ssl/certs "$OPENSSL11_PREFIX/ssl/certs"; \
	ln -s /etc/ssl/certs/ca-certificates.crt "$OPENSSL11_PREFIX/ssl/cert.pem"; \
	cd /; \
	rm -rf /usr/src/openssl /usr/src/openssl.tar.gz /usr/src/openssl.tar.gz.asc; \
	\
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	"$OPENSSL11_PREFIX/bin/openssl" version

ENV PHP_SRC_REPO="https://github.com/php/php-src.git" \
	PHP_SRC_BRANCH="PHP-7.4-CVE-2026-109618-109619" \
	PHP_SRC_COMMIT="712e60f9edfd03f0960fc4fc3c2c375f42b90aa2"

# version string the backport branch reports (configure.ac AC_INIT)
ENV PHP_VERSION 7.4.34-dev

# release tarballs ship the PEAR installer, git does not: pinned copy
ENV PEAR_PHAR_URL="https://pear.php.net/install-pear-nozlib.phar" \
	PEAR_PHAR_SHA256="a71349da29f1a6e3f0792695b167e582375a93c70c0e9d35e7c4675697c5f039"

# Integrity: the commit is fetched by its full SHA and re-checked with
# "git rev-parse"; git object ids make the tree content-addressed.
RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends git; \
	rm -rf /var/lib/apt/lists/*; \
	\
	mkdir -p /usr/src/php-src; \
	cd /usr/src/php-src; \
	git init -q; \
	for i in 1 2 3; do \
		git fetch -q --depth 1 "$PHP_SRC_REPO" "$PHP_SRC_COMMIT" && break; \
		[ "$i" -lt 3 ]; sleep $((i * 15)); \
	done; \
	git -c advice.detachedHead=false checkout -q FETCH_HEAD; \
	test "$(git rev-parse HEAD)" = "$PHP_SRC_COMMIT"; \
	grep -qF "AC_INIT([PHP],[$PHP_VERSION]," configure.ac; \
	rm -rf .git; \
	./buildconf --force; \
	curl -fsSL --retry 5 --retry-all-errors -o pear/install-pear-nozlib.phar "$PEAR_PHAR_URL"; \
	echo "$PEAR_PHAR_SHA256 *pear/install-pear-nozlib.phar" | sha256sum -c -; \
	cd /usr/src; \
	tar -cJf php.tar.xz php-src; \
	rm -rf php-src; \
	\
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

COPY docker-php-source /usr/local/bin/

RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		apache2-dev \
		bison \
		libargon2-dev \
		libcurl4-openssl-dev \
		libonig-dev \
		libreadline-dev \
		libsodium-dev \
		libsqlite3-dev \
		libxml2-dev \
		zlib1g-dev \
	; \
	\
	export \
		CFLAGS="$PHP_CFLAGS" \
		CPPFLAGS="$PHP_CPPFLAGS" \
		LDFLAGS="$PHP_LDFLAGS -Wl,-rpath,$OPENSSL11_PREFIX/lib" \
		PKG_CONFIG_PATH="$OPENSSL11_PREFIX/lib/pkgconfig" \
# https://github.com/php/php-src/blob/d6299206dd828382753453befd1b915491b741c6/configure.ac#L1496-L1511
		PHP_BUILD_PROVIDER='https://github.com/stufently/php-patched-images' \
		PHP_UNAME='Linux - Docker' \
	; \
	docker-php-source extract; \
	cd /usr/src/php; \
	gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
# https://bugs.php.net/bug.php?id=74125
	if [ ! -d /usr/include/curl ]; then \
		ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl; \
	fi; \
	test "$PHP_INI_DIR" != "${PHP_INI_DIR%/php}"; \
	./configure \
		--build="$gnuArch" \
		"PHP_BACKPORT_COMMIT=$PHP_SRC_COMMIT" \
		--sysconfdir="${PHP_INI_DIR%/php}" \
		--with-config-file-path="$PHP_INI_DIR" \
		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
		\
# make sure invalid --configure-flags are fatal errors instead of just warnings
		--enable-option-checking=fatal \
		\
# https://github.com/docker-library/php/issues/439
		--with-mhash \
		\
# https://github.com/docker-library/php/issues/822
		--with-pic \
		\
# --enable-ftp is included here for compatibility with existing versions. ftp_ssl_connect() needed ftp to be compiled statically before PHP 7.0 (see https://github.com/docker-library/php/issues/236).
		--enable-ftp \
# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
		--enable-mbstring \
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
		--enable-mysqlnd \
# https://wiki.php.net/rfc/argon2_password_hash
		--with-password-argon2 \
# https://wiki.php.net/rfc/libsodium
		--with-sodium=shared \
# always build against system sqlite3 (https://github.com/php/php-src/commit/6083a387a81dbbd66d6316a3a12a63f06d5f7109)
		--with-pdo-sqlite=/usr \
		--with-sqlite3=/usr \
		\
		--with-curl \
		--with-iconv \
		--with-openssl \
		--with-readline \
		--with-zlib \
		\
# https://github.com/bwoebi/phpdbg-docs/issues/1#issuecomment-163872806 ("phpdbg is primarily a CLI debugger, and is not suitable for debugging an fpm stack.")
		--disable-phpdbg \
		\
# in PHP 7.4+, the pecl/pear installers are officially deprecated (requiring an explicit "--with-pear")
		--with-pear \
		\
# bundled pcre does not support JIT on riscv64 until 10.41 (php 8.3+)
# https://github.com/PCRE2Project/pcre2/commits/pcre2-10.41/src/sljit/sljitNativeRISCV_64.c
# https://github.com/php/php-src/tree/php-8.3.0/ext/pcre/pcre2lib
		$(test "$gnuArch" = 'riscv64-linux-gnu' && echo '--without-pcre-jit') \
		--with-libdir="lib/$debMultiarch" \
		\
		--disable-cgi \
		\
		--with-apxs2 \
	; \
	make -j "$(nproc)"; \
	find -type f -name '*.a' -delete; \
	make install; \
	find \
		/usr/local \
		-type f \
		-perm '/0111' \
		-exec sh -euxc ' \
			strip --strip-all "$@" || : \
		' -- '{}' + \
	; \
	make clean; \
	\
# https://github.com/docker-library/php/issues/692 (copy default example "php.ini" files somewhere easily discoverable)
	cp -v php.ini-* "$PHP_INI_DIR/"; \
	\
	cd /; \
	docker-php-source delete; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
		| sort -u \
		| xargs -rt dpkg-query --search \
# https://manpages.debian.org/trixie/dpkg/dpkg-query.1.en.html#S (we ignore diversions and it'll be really unusual for more than one package to provide any given .so file)
		| awk 'sub(":$", "", $1) { print $1 }' \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*; \
	\
# update pecl channel definitions https://github.com/docker-library/php/issues/443
	pecl update-channels; \
	rm -rf /tmp/pear ~/.pearrc; \
	\
# smoke test
	php --version

COPY docker-php-ext-* docker-php-entrypoint /usr/local/bin/

# enable OPcache by default (https://wiki.php.net/rfc/make_opcache_required)
RUN docker-php-ext-enable opcache

# sodium was built as a shared module (so that it can be replaced later if so desired), so let's enable it too (https://github.com/docker-library/php/issues/598)
RUN docker-php-ext-enable sodium

LABEL org.opencontainers.image.version="7.4.34-dev-backport-712e60f9edfd03f0960fc4fc3c2c375f42b90aa2" \
      org.opencontainers.image.revision.php-src="712e60f9edfd03f0960fc4fc3c2c375f42b90aa2"

ENTRYPOINT ["docker-php-entrypoint"]
# https://httpd.apache.org/docs/2.4/stopping.html#gracefulstop
STOPSIGNAL SIGWINCH

COPY apache2-foreground /usr/local/bin/
WORKDIR /var/www/html

EXPOSE 80
CMD ["apache2-foreground"]
