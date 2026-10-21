#!/usr/bin/env bash
# Refresh core/<branch>/<variant>/ from docker-library/php at a given commit
# and pin the Debian base image by digest.
# Usage: scripts/sync-upstream.sh <docker-library/php commit sha>
set -euo pipefail

SHA=${1:?commit sha of github.com/docker-library/php}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

git clone -q https://github.com/docker-library/php.git "$TMP/php"
git -C "$TMP/php" checkout -q "$SHA"
digest=$(docker buildx imagetools inspect debian:trixie-slim --format '{{json .Manifest}}' | jq -r .digest)
[[ $digest == sha256:* ]] || { echo "cannot resolve debian:trixie-slim digest" >&2; exit 1; }

for b in 8.2 8.3 8.4 8.5; do
  for v in cli fpm apache; do
    rm -rf "$ROOT/core/$b/$v"; mkdir -p "$ROOT/core/$b/$v"
    cp -a "$TMP/php/$b/trixie/$v/." "$ROOT/core/$b/$v/"
    sed -i "s|^FROM debian:trixie-slim\$|FROM debian:trixie-slim@$digest|" "$ROOT/core/$b/$v/Dockerfile"
  done
done
echo "$SHA" > "$ROOT/core/UPSTREAM_COMMIT"
grep -h '^ENV PHP_VERSION' "$ROOT"/core/*/*/Dockerfile | sort -u
