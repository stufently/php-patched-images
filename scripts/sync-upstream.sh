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

# Upstream runs `gpgconf --kill all; rm -rf "$GNUPGHOME"`: the agent sockets
# vanish asynchronously, so rm can hit ENOENT on S.dirmngr and fail the build.
# Retry rm once after a pause; `gpg --verify` above it is left untouched.
gpg_cleanup() { # <Dockerfile>
  grep -qF 'gpgconf --kill all;' "$1" || return 0
  sed -i 's/^\(\t*\)rm -rf "\$GNUPGHOME"; \\$/\1rm -rf "$GNUPGHOME" || { sleep 1; rm -rf "$GNUPGHOME"; }; \\/' "$1"
  grep -q 'rm -rf "$GNUPGHOME" || { sleep 1;' "$1" || { echo "gpg cleanup patch did not apply to $1" >&2; return 1; }
}

# Copy $ROOT/patches/<branch>/*.patch into the image build context and tell
# the Dockerfile to apply them after `docker-php-source extract`. sync
# rewrites core/ from upstream, so a hand edit there would disappear on the
# next run; the apply step has to live here. /usr/src/php-patches/ stays in
# the image as visible proof of which patch was applied. The loop runs under
# `set -eux` and fails the build when a patch does not apply, is already
# applied (`--forward`), or the directory is empty.
# убрать patches/8.4 при переходе на 8.4.28, patches/8.5 — на 8.5.13 (фикс войдёт в релиз).
add_patches() { # <branch> <dst>
  local branch=$1 dst=$2
  local src="$ROOT/patches/$branch" df="$dst/Dockerfile"
  [ -d "$src" ] || return 0
  local names=() name
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    names+=("$(basename "$name")")
  done < <(find "$src" -maxdepth 1 -type f -name '*.patch' | LC_ALL=C sort)
  [ ${#names[@]} -gt 0 ] || return 0

  mkdir -p "$dst/patches"
  local n
  for n in "${names[@]}"; do
    cp -a "$src/$n" "$dst/patches/$n"
  done

  local ids="" part
  for part in "${names[@]}"; do
    part=${part%.patch}
    if [ -z "$ids" ]; then ids=$part; else ids="$ids $part"; fi
  done

  local alpine=0
  [[ $dst == */alpine/* ]] && alpine=1
  local copy_line='COPY patches/ /usr/src/php-patches/'
  local apply_line=$'\tfor p in /usr/src/php-patches/*.patch; do patch -p1 --forward --batch --fuzz=0 -i "$p"; done; \\'
  local env_line="ENV PHP_PATCHES=\"${ids}\""
  local label_line="LABEL org.opencontainers.image.php-src.patches=\"${ids}\""
  local apk_line=$'\t\tpatch \\'
  local tmp
  tmp=$(mktemp)
  GH_COPY_LINE=$copy_line \
  GH_APPLY_LINE=$apply_line \
  GH_ENV_LINE=$env_line \
  GH_LABEL_LINE=$label_line \
  GH_APK_LINE=$apk_line \
  GH_ALPINE=$alpine \
  awk '
BEGIN {
  copy_anchor = "COPY docker-php-source /usr/local/bin/"
  extract = "\tdocker-php-source extract; \\"
  cdline = "\tcd /usr/src/php; \\"
  apk = "\tapk add --no-cache --virtual .build-deps \\"
  phpize = "\t\t$PHPIZE_DEPS \\"
}
{
  print
  if ($0 == copy_anchor) print ENVIRON["GH_COPY_LINE"]
  if (prev == extract && $0 == cdline) print ENVIRON["GH_APPLY_LINE"]
  if ($0 ~ /^ENV PHP_VERSION /) {
    print ENVIRON["GH_ENV_LINE"]
    print ENVIRON["GH_LABEL_LINE"]
  }
  if (ENVIRON["GH_ALPINE"] == "1" && prev == apk && $0 == phpize) print ENVIRON["GH_APK_LINE"]
  prev = $0
}
' "$df" > "$tmp"
  cat "$tmp" > "$df"
  rm -f "$tmp"

  local got
  got=$(grep -cxF "$copy_line" "$df" || true)
  [ "$got" = 1 ] || { echo "COPY patches did not apply to $df" >&2; return 1; }
  got=$(grep -cxF "$apply_line" "$df" || true)
  [ "$got" = 1 ] || { echo "patch apply loop did not apply to $df" >&2; return 1; }
  got=$(grep -cxF "$env_line" "$df" || true)
  [ "$got" = 1 ] || { echo "ENV PHP_PATCHES did not apply to $df" >&2; return 1; }
  got=$(grep -cxF "$label_line" "$df" || true)
  [ "$got" = 1 ] || { echo "patches LABEL did not apply to $df" >&2; return 1; }
  got=$(grep -cxF "$apk_line" "$df" || true)
  if [ "$alpine" = 1 ]; then
    [ "$got" = 1 ] || { echo "patch build-dep did not apply to $df" >&2; return 1; }
  else
    [ "$got" = 0 ] || { echo "patch build-dep did not apply to $df" >&2; return 1; }
  fi
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
      gpg_cleanup "$dst/Dockerfile"
      add_patches "$b" "$dst"
    done
  done
}

sync_os trixie trixie debian:trixie-slim cli fpm apache
sync_os bookworm bookworm debian:bookworm-slim cli fpm apache
sync_os alpine "alpine$ALPINE" "alpine:$ALPINE" cli fpm

echo "$SHA" > "$ROOT/core/UPSTREAM_COMMIT"
grep -h '^ENV PHP_VERSION' "$ROOT"/core/8.*/*/*/Dockerfile | sort -u
