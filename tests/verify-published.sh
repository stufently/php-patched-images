#!/usr/bin/env bash
# Check the published multi-arch tags the way an anonymous user sees them:
# empty DOCKER_CONFIG (no login), `docker manifest inspect`, `docker run php -v`.
# Usage: tests/verify-published.sh <amd64|arm64> [<YYYYMMDD snapshot stamp>] [<tag regex>]
#   The tag set comes from the targets in .github/workflows/build.yml and
#   scripts/build.sh (LIST_ONLY=1). Every tag of an image (branch, pinned,
#   aliases) must resolve to the same index with linux/amd64 + linux/arm64;
#   the dated snapshot (if a stamp is given) must exist with both platforms
#   but may differ, since snapshots are never overwritten by later rebuilds.
#   The image is then run on <arch>.
set -euo pipefail

ARCH=$1 STAMP=${2:-} FILTER=${3:-.}
IMAGE=${IMAGE:-ghcr.io/stufently/php-patched-images}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DOCKER_CONFIG=$(mktemp -d); export DOCKER_CONFIG
trap 'rm -rf "$DOCKER_CONFIG"' EXIT

declare -A BACKPORT=([7.4]=712e60f9edfd03f0960fc4fc3c2c375f42b90aa2 [8.1]=1d7dec178a094e6e75b229ce22754045f8c6070a)
fails=0 checked=0
bad() { echo "FAIL $*"; fails=$((fails + 1)); }

grep -o '{"branch":"[^"]*","os":"[^"]*","variant":"[^"]*"}' "$ROOT/.github/workflows/build.yml" \
  | sed -E 's/.*"branch":"([^"]*)","os":"([^"]*)","variant":"([^"]*)".*/\1 \2 \3/' > "$DOCKER_CONFIG/targets"
[ -s "$DOCKER_CONFIG/targets" ] || { echo "no targets found in build.yml" >&2; exit 1; }

while read -r b o v; do
  LIST_ONLY=1 "$ROOT/scripts/build.sh" "$b" "$o" "$v"
done < "$DOCKER_CONFIG/targets" > "$DOCKER_CONFIG/images"

while read -r _ _ _ commit primary pinned aliases; do
  [[ $primary =~ $FILTER ]] || continue
  f0=$fails
  tags=("$primary" "$pinned")
  for a in $aliases; do tags+=("$a"); done
  [ -z "$STAMP" ] || tags+=("$pinned-$STAMP")
  ref=""
  for t in "${tags[@]}"; do
    snapshot=no; [ -z "$STAMP" ] || [ "$t" != "$pinned-$STAMP" ] || snapshot=yes
    if ! docker manifest inspect "$IMAGE:$t" > "$DOCKER_CONFIG/m.json" 2>"$DOCKER_CONFIG/m.err"; then
      bad "$t: manifest inspect: $(head -c 200 "$DOCKER_CONFIG/m.err")"; continue
    fi
    plats=$(jq -r '[.manifests[]? | select(.platform.os=="linux") | .platform.architecture] | sort | unique | join(",")' "$DOCKER_CONFIG/m.json")
    [ "$plats" = "amd64,arm64" ] || bad "$t: platforms '$plats'"
    sum=$(sha256sum < "$DOCKER_CONFIG/m.json" | cut -d' ' -f1)
    [ "$snapshot" = no ] || continue
    if [ -z "$ref" ]; then ref=$sum; elif [ "$sum" != "$ref" ]; then bad "$t: differs from $primary"; fi
  done
  docker pull -q --platform "linux/$ARCH" "$IMAGE:$primary" >/dev/null 2>&1 || bad "$primary: pull for $ARCH failed"
  rc=0; full=$(docker run --rm --platform "linux/$ARCH" "$IMAGE:$primary" php -v 2>&1) || rc=$?
  out=${full%%$'\n'*}
  [ "$rc" -eq 0 ] || bad "$primary ($ARCH): php -v exited $rc"
  if [ "$commit" = - ]; then
    want="PHP ${pinned%%-*} "
  else
    br=${primary%%-backport*}
    [ "${BACKPORT[$br]:-}" = "$commit" ] || bad "$primary: unexpected commit $commit"
    want="PHP $([ "$br" = 7.4 ] && echo 7.4.34-dev || echo 8.1.34) "
    rc=0; info=$(docker run --rm --platform "linux/$ARCH" "$IMAGE:$primary" php -i 2>&1) || rc=$?
    [ "$rc" -eq 0 ] || bad "$primary ($ARCH): php -i exited $rc"
    got=$(grep -o 'PHP_BACKPORT_COMMIT=[0-9a-f]*' <<<"$info" | head -1) || true
    [ "$got" = "PHP_BACKPORT_COMMIT=$commit" ] || bad "$primary ($ARCH): backport commit '$got'"
  fi
  [[ $out == "$want"* ]] || bad "$primary ($ARCH): php -v '$out', want '$want...'"
  [ "$fails" -eq "$f0" ] && echo "ok $primary ($ARCH): $out [${#tags[@]} tags]"
  checked=$((checked + 1))
  docker rmi "$IMAGE:$primary" >/dev/null 2>&1 || true
done < "$DOCKER_CONFIG/images"

echo "checked $checked images on $ARCH, $fails failure(s)"
[ "$checked" -gt 0 ] && [ "$fails" -eq 0 ]
