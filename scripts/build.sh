#!/usr/bin/env bash
# Build core + all profiles for one branch/os/variant on the local Docker daemon.
# Usage: scripts/build.sh <branch> <os> <variant> [tag-prefix]
#   branch:  8.2 | 8.3 | 8.4 | 8.5 | 7.4-backport | 8.1-backport
#   os:      trixie | bookworm | alpine   (backports: bookworm only)
#   variant: cli | fpm | apache          (alpine: cli | fpm)
#
# Appends one line per image to $BUILT_LIST (if set):
#   <local-image> <variant> <profile> <backport-commit|-> <tag> <tag>...
# Tags are the published names without registry and arch. The first one is
# the primary (mutable branch tag), the second the pinned one (exact PHP
# version, or the php-src commit for backports) from which CI derives the
# dated snapshot tag.
# LIST_ONLY=1: only print those lines (to stdout), build nothing.
set -euo pipefail

BRANCH=$1 OS=$2 VARIANT=$3 PREFIX=${4:-local/php-patched}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ALPINE=3.24
DIR="$ROOT/core/$BRANCH/$OS/$VARIANT"

[ -d "$DIR" ] || { echo "no core/$BRANCH/$OS/$VARIANT" >&2; exit 1; }

# Same profile set on every branch (8.2-8.5, 7.4/8.1 backports) and every OS.
# dev (Xdebug) is built for cli and fpm only.
profiles_for() { # <variant>
  case $1 in
    cli|fpm) echo "base web app dev" ;;
    apache)  echo "base web app" ;;
  esac
}

# docker build, retried up to 2 more times (30s, then 60s pause) ONLY when
# its log shows a registry/network error (Docker Hub 5xx on the dockerfile
# frontend or a base image, dropped connection). Any other failure, e.g. a
# compile error, fails at once. Smoke tests run outside this script and are
# never retried.
REGISTRY_ERR='unexpected status from (HEAD|GET) request to [^ ]+: 5[0-9][0-9]|httpReadSeeker: failed open|failed to do request|TLS handshake timeout|i/o timeout|connection reset by peer|toomanyrequests'
dbuild() {
  local log attempt rc
  log=$(mktemp)
  for attempt in 1 2 3; do
    rc=0
    docker build "$@" 2>&1 | tee "$log" || rc=$?
    [ "$rc" -ne 0 ] || { rm -f "$log"; return 0; }
    if [ "$attempt" -lt 3 ] && grep -Eq "$REGISTRY_ERR" "$log"; then
      echo "::warning::docker build: registry/network error, retry $attempt/2 in $((attempt * 30))s" >&2
      sleep $((attempt * 30))
      continue
    fi
    rm -f "$log"
    return "$rc"
  done
}

envval() { awk -v k="$1" '$1=="ENV" && $2==k {print $3; exit}' "$DIR/Dockerfile" | tr -d '"'; }

commit=-
case $BRANCH in
  *-backport)
    commit=$(sed -n 's/^.*PHP_SRC_COMMIT="\([0-9a-f]\{40\}\)".*$/\1/p' "$DIR/Dockerfile")
    [ -n "$commit" ] || { echo "no PHP_SRC_COMMIT in $DIR/Dockerfile" >&2; exit 1; }
    pinned="$BRANCH-${commit:0:7}"
    ;;
  *)
    pinned=$(envval PHP_VERSION)
    [ -n "$pinned" ] || { echo "no PHP_VERSION in $DIR/Dockerfile" >&2; exit 1; }
    ;;
esac

case $OS in trixie) os_sfx=() ;; bookworm) os_sfx=(-bookworm) ;; alpine) os_sfx=(-alpine "-alpine$ALPINE") ;; esac
[[ $BRANCH == *-backport ]] && os_sfx=()   # one base only, documented in README

profiles=$(profiles_for "$VARIANT")
[ -n "$profiles" ] || { echo "no profiles for $BRANCH/$OS/$VARIANT" >&2; exit 1; }

core="$PREFIX-core:$BRANCH-$OS-$VARIANT"
[ "${LIST_ONLY:-}" = 1 ] || dbuild --pull -t "$core" "$DIR"

for p in $profiles; do
  name="$VARIANT"; [ "$p" = base ] || name="$VARIANT-$p"
  tags=()
  if [ ${#os_sfx[@]} -eq 0 ]; then
    tags=("$BRANCH-$name" "$pinned-$name")
  else
    tags=("$BRANCH-$name${os_sfx[0]}" "$pinned-$name${os_sfx[0]}")
    for s in "${os_sfx[@]:1}"; do tags+=("$BRANCH-$name$s" "$pinned-$name$s"); done
  fi
  local_tag="$PREFIX:${tags[0]}"
  if [ "${LIST_ONLY:-}" = 1 ]; then
    echo "$local_tag $VARIANT $p $commit ${tags[*]}"
    continue
  fi
  dbuild --build-arg BASE_IMAGE="$core" --target "$p" -t "$local_tag" "$ROOT"
  echo "$local_tag $VARIANT $p $commit ${tags[*]}" >> "${BUILT_LIST:-/dev/null}"
done
