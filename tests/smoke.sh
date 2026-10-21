#!/usr/bin/env bash
# Smoke test for one image.
# Usage: tests/smoke.sh <image> <cli|fpm|apache> <base|web|app|dev>
set -euo pipefail

IMAGE=$1 VARIANT=$2 PROFILE=$3
HERE=$(cd "$(dirname "$0")" && pwd)

fail() { echo "FAIL [$IMAGE]: $*" >&2; exit 1; }

# First versions of each branch that contain the fixes for
# CVE-2026-109618 / CVE-2026-109619 (php.net, 2026-10-21).
declare -A FIXED=([8.2]=8.2.35 [8.3]=8.3.36 [8.4]=8.4.27 [8.5]=8.5.12)

run() { docker run --rm --entrypoint php "$IMAGE" "$@"; }

ver=$(run -r 'echo PHP_VERSION;')
branch=${ver%.*}
need=${FIXED[$branch]:-}
[ -n "$need" ] || fail "unknown PHP branch $branch (version $ver)"
ok=$(run -r "echo version_compare(PHP_VERSION, '$need', '>=') ? 'yes' : 'no';")
[ "$ok" = yes ] || fail "PHP $ver is older than fixed $need"
run -v | head -1 | grep -q "^PHP $ver " || fail "php -v does not report $ver"
echo "version: $ver (>= $need)"

case $PROFILE in
  base) exts=() ;;
  web)  exts=(bcmath exif gd intl mysqli pdo_mysql zip imagick) ;;
  app)  exts=(bcmath exif gd intl pcntl pdo_mysql pdo_pgsql pgsql sockets zip redis apcu) ;;
  dev)  exts=(bcmath exif gd intl pcntl pdo_mysql pdo_pgsql pgsql sockets zip redis apcu xdebug) ;;
  *) fail "unknown profile $PROFILE" ;;
esac
exts+=("Zend OPcache" curl mbstring openssl sodium PDO)

mods=$(run -m)
for e in "${exts[@]}"; do
  grep -qxiF "$e" <<<"$mods" || fail "extension '$e' missing"
done
# php -m must not print startup warnings (broken/duplicate ext load)
[ "$(run -r 'echo "ok";' 2>&1)" = ok ] || fail "php prints warnings on startup"
case $PROFILE in app|dev) docker run --rm --entrypoint composer "$IMAGE" --version >/dev/null 2>&1 || fail "composer missing" ;; esac
echo "extensions: ok (${#exts[@]} checked)"

cleanup() { [ -n "${cid:-}" ] && docker rm -f "$cid" >/dev/null 2>&1 || true; }
trap cleanup EXIT

case $VARIANT in
  cli) ;;
  fpm)
    docker run --rm "$IMAGE" php-fpm -t >/dev/null 2>&1 || fail "php-fpm -t failed"
    cid=$(docker run -d -v "$HERE:/smoke:ro" -v "$HERE/www:/var/www/html:ro" "$IMAGE")
    out=""
    for _ in $(seq 1 20); do
      out=$(docker exec "$cid" php /smoke/fcgi_get.php 127.0.0.1 9000 /var/www/html/index.php 2>/dev/null || true)
      [ -n "$out" ] && break; sleep 1
    done
    grep -q "^SMOKE-OK $ver fpm-fcgi opcache=1 expose_php=0$" <<<"$out" || { docker logs "$cid" >&2; fail "fpm request failed: '$out'"; }
    echo "fpm: $out"
    ;;
  apache)
    cid=$(docker run -d -v "$HERE/www:/var/www/html:ro" "$IMAGE")
    out=""
    for _ in $(seq 1 20); do
      out=$(docker exec "$cid" php -r 'echo @file_get_contents("http://127.0.0.1/index.php");' 2>/dev/null || true)
      [ -n "$out" ] && break; sleep 1
    done
    grep -q "^SMOKE-OK $ver apache2handler opcache=1 expose_php=0$" <<<"$out" || { docker logs "$cid" >&2; fail "apache request failed: '$out'"; }
    echo "apache: $out"
    ;;
  *) fail "unknown variant $VARIANT" ;;
esac
echo "PASS $IMAGE"
