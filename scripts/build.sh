#!/usr/bin/env bash
# Build core + all profiles for one branch/variant on the local Docker daemon.
# Usage: scripts/build.sh <8.2|8.3|8.4|8.5> <cli|fpm|apache> [tag-prefix]
# Result tags: <prefix>:<branch>-<variant>[-<profile>]   (base has no suffix)
set -euo pipefail

BRANCH=$1 VARIANT=$2 PREFIX=${3:-local/php-patched}
ROOT=$(cd "$(dirname "$0")/.." && pwd)

profiles_for() {
  case $1 in
    cli)    echo "base app dev" ;;
    fpm)    echo "base web app dev" ;;
    apache) echo "base web app" ;;
    *) echo "unknown variant $1" >&2; return 1 ;;
  esac
}

[ -d "$ROOT/core/$BRANCH/$VARIANT" ] || { echo "no core/$BRANCH/$VARIANT" >&2; exit 1; }

core="$PREFIX-core:$BRANCH-$VARIANT"
docker build --pull -t "$core" "$ROOT/core/$BRANCH/$VARIANT"

for p in $(profiles_for "$VARIANT"); do
  tag="$PREFIX:$BRANCH-$VARIANT"; [ "$p" = base ] || tag="$tag-$p"
  docker build --build-arg BASE_IMAGE="$core" --target "$p" -t "$tag" "$ROOT"
  echo "$tag $VARIANT $p" >> "${BUILT_LIST:-/dev/null}"
done
