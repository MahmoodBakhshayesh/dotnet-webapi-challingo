#!/usr/bin/env bash
# Build and push Worker image (reads api.env). Build context = challingo-api folder.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/load-env.sh" "$SCRIPT_DIR/api.env"

DOCKER_PREFIX="challingo"
MONOREPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
API_ROOT="$MONOREPO_ROOT/challingo-api"
IMAGE="$REGISTRY/${DOCKER_PREFIX}-worker:$TAG"
DOCKERFILE="$API_ROOT/Challingo.Worker/Dockerfile"

test_registry "$REGISTRY"
assert_insecure_registry "$REGISTRY"
ensure_buildx

if [[ ! -f "$DOCKERFILE" ]]; then
  echo "Missing $DOCKERFILE" >&2
  exit 1
fi

echo "=== Worker $IMAGE ==="
(
  cd "$API_ROOT"
  docker buildx build --platform linux/amd64 -f "$DOCKERFILE" -t "$IMAGE" --load .
)
docker push "$IMAGE"

echo "Done. Run sync-server-env.sh, copy server-files/ to VPS, run ./server-up.sh"
