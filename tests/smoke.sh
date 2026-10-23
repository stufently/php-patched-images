#!/usr/bin/env bash
# Smoke test for one image.
# Usage: tests/smoke.sh <image> <cli|fpm|apache> <base|web|app|dev> [backport-commit]
# With a backport commit (7.4 / 8.1 images built from the php-src backport
# branches) the version check is replaced by a check that the PHP binaries
# (CLI and the SAPI under test) were configured from exactly that commit.
set -euo pipefail

IMAGE=$1 VARIANT=$2 PROFILE=$3 COMMIT=${4:--}
[ "$COMMIT" = - ] && COMMIT=""
HERE=$(cd "$(dirname "$0")" && pwd)

fail() { echo "FAIL [$IMAGE]: $*" >&2; exit 1; }

# First versions of each branch that contain the fixes for
# CVE-2026-109618 / CVE-2026-109619 (php.net, 2026-10-21).
declare -A FIXED=([8.2]=8.2.35 [8.3]=8.3.36 [8.4]=8.4.27 [8.5]=8.5.12)

run() { docker run --rm --entrypoint php "$IMAGE" "$@"; }

# Backport branches: php-src commit compiled in via configure (phpinfo
# "Configure Command"), see core/*-backport/*/*/Dockerfile.
declare -A BACKPORT=([7.4]=712e60f9edfd03f0960fc4fc3c2c375f42b90aa2 [8.1]=1d7dec178a094e6e75b229ce22754045f8c6070a)

ver=$(run -r 'echo PHP_VERSION;')
branch=$(cut -d. -f1-2 <<<"$ver")
run -v | head -1 | grep -q "^PHP $ver " || fail "php -v does not report $ver"
if [ -n "$COMMIT" ]; then
  [ "${BACKPORT[$branch]:-}" = "$COMMIT" ] || fail "PHP $ver: expected backport commit for $branch is '${BACKPORT[$branch]:-none}', not $COMMIT"
  # shellcheck disable=SC2016 # PHP code, not shell
  built=$(run -r 'ob_start(); phpinfo(INFO_GENERAL); echo preg_match("/PHP_BACKPORT_COMMIT=([0-9a-f]{40})/", ob_get_clean(), $m) ? $m[1] : "none";')
  [ "$built" = "$COMMIT" ] || fail "CLI was not built from backport commit $COMMIT (found: $built)"
  label=$(docker inspect --format '{{index .Config.Labels "org.opencontainers.image.revision.php-src"}}' "$IMAGE")
  [ "$label" = "$COMMIT" ] || fail "label org.opencontainers.image.revision.php-src is '$label', not $COMMIT"
  echo "version: $ver, backport commit $COMMIT (cli)"
else
  need=${FIXED[$branch]:-}
  [ -n "$need" ] || fail "unknown PHP branch $branch (version $ver)"
  ok=$(run -r "echo version_compare(PHP_VERSION, '$need', '>=') ? 'yes' : 'no';")
  [ "$ok" = yes ] || fail "PHP $ver is older than fixed $need"
  echo "version: $ver (>= $need)"
fi

# GH-24488: on 8.4.27 / 8.5.12 the GC double-frees the SimpleXMLElement
# properties table (zend_mm_heap corrupted, rc=139). Both repros must print
# exactly "done". Those two releases must also ship PHP_PATCHES containing
# gh24488; other versions are not required to.
for f in gh24488-repro.php gh24488-repro-json.php; do
  rc=0
  out=$(docker run --rm --entrypoint php -v "$HERE:/smoke:ro" "$IMAGE" "/smoke/$f" 2>&1) || rc=$?
  [ "$rc" = 0 ] && [ "$out" = done ] || fail "gh24488 repro $f: rc=$rc ${out}"
done
patches=$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$IMAGE" | sed -n 's/^PHP_PATCHES=//p' || true)
case $ver in
  8.4.27|8.5.12)
    case $patches in
      *gh24488*) ;;
      *) fail "gh24488: PHP $ver env PHP_PATCHES='${patches}' does not contain gh24488" ;;
    esac
    ;;
esac
echo "gh24488: ok (patches: ${patches:-none})"

case $PROFILE in
  base) exts=() ;;
  web)  exts=(bcmath exif gd intl ldap mysqli pdo_mysql soap zip imagick memcached) ;;
  app)  exts=(bcmath exif gd intl ldap pcntl pdo_mysql pdo_pgsql pgsql soap sockets zip redis apcu memcached) ;;
  dev)  exts=(bcmath exif gd intl ldap pcntl pdo_mysql pdo_pgsql pgsql soap sockets zip redis apcu memcached xdebug) ;;
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
    if [ -n "$COMMIT" ]; then
      out=$(docker exec "$cid" php /smoke/fcgi_get.php 127.0.0.1 9000 /var/www/html/build.php 2>/dev/null || true)
      [ "$out" = "BUILD $ver fpm-fcgi $COMMIT" ] || fail "php-fpm was not built from backport commit: '$out'"
      echo "fpm: $out"
    fi
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
    if [ -n "$COMMIT" ]; then
      out=$(docker exec "$cid" php -r 'echo @file_get_contents("http://127.0.0.1/build.php");' 2>/dev/null || true)
      [ "$out" = "BUILD $ver apache2handler $COMMIT" ] || fail "mod_php was not built from backport commit: '$out'"
      echo "apache: $out"
    fi
    ;;
  *) fail "unknown variant $VARIANT" ;;
esac
echo "PASS $IMAGE"
