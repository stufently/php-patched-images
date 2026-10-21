#!/usr/bin/env bash
# Refresh core/<branch>/<os>/<variant>/ from docker-library/php at a given
# commit and pin each base image by digest.
# Usage: scripts/sync-upstream.sh <docker-library/php commit sha>
#
#   os       upstream dir   base image           variants
#   trixie   trixie         debian:trixie-slim   cli fpm apache
#   bookworm bookworm       debian:bookworm-slim cli fpm apache
#   alpine   alpine$ALPINE  alpine:$ALPINE       cli fpm
#
# core/*-backport/ (7.4 / 8.1 from php-src backport branches) is NOT synced
# from upstream: those Dockerfiles are maintained here by hand.
set -euo pipefail

SHA=${1:?commit sha of github.com/docker-library/php}
ALPINE=3.24
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

git clone -q https://github.com/docker-library/php.git "$TMP/php"
git -C "$TMP/php" checkout -q "$SHA"

pin() { # <image> -> digest of the multi-arch index
  local d
  d=$(docker buildx imagetools inspect "$1" --format '{{json .Manifest}}' | jq -r .digest)
  [[ $d == sha256:* ]] || { echo "cannot resolve $1 digest" >&2; return 1; }
  echo "$d"
}

sync_os() { # <os> <upstream dir> <base image> <variants...>
  local os=$1 up=$2 img=$3; shift 3
  local digest; digest=$(pin "$img")
  for b in 8.2 8.3 8.4 8.5; do
    for v in "$@"; do
      local dst="$ROOT/core/$b/$os/$v"
      rm -rf "$dst"; mkdir -p "$dst"
      cp -a "$TMP/php/$b/$up/$v/." "$dst/"
      grep -qx "FROM $img" "$dst/Dockerfile" || { echo "unexpected FROM in $b/$up/$v" >&2; return 1; }
      sed -i "s|^FROM $img\$|FROM $img@$digest|" "$dst/Dockerfile"
    done
  done
}

sync_os trixie trixie debian:trixie-slim cli fpm apache
sync_os bookworm bookworm debian:bookworm-slim cli fpm apache
sync_os alpine "alpine$ALPINE" "alpine:$ALPINE" cli fpm

echo "$SHA" > "$ROOT/core/UPSTREAM_COMMIT"
grep -h '^ENV PHP_VERSION' "$ROOT"/core/8.*/*/*/Dockerfile | sort -u
