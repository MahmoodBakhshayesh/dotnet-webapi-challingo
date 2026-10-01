#!/usr/bin/env bash
# Build and push Web image (reads web.env in this folder).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/load-env.sh" "$SCRIPT_DIR/web.env"

DOCKER_PREFIX="challingo"
MONOREPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_ROOT="$MONOREPO_ROOT/challingo-web"
IMAGE="$REGISTRY/${DOCKER_PREFIX}-web:$TAG"

test_registry "$REGISTRY"
assert_insecure_registry "$REGISTRY"
ensure_buildx

echo "=== Web $IMAGE ==="
(
  cd "$WEB_ROOT"
  docker buildx build --platform linux/amd64 -f Dockerfile -t "$IMAGE" --load \
    --build-arg "NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL:-/api}" \
    --build-arg "NEXT_PUBLIC_WS_URL=${NEXT_PUBLIC_WS_URL:-http://localhost:8080}" \
    --build-arg "NEXT_PUBLIC_MAP_API_KEY=${NEXT_PUBLIC_MAP_API_KEY:-}" \
    --build-arg "NEXT_PUBLIC_MAP_USE_WMS=${NEXT_PUBLIC_MAP_USE_WMS:-false}" \
    --build-arg "NEXT_PUBLIC_MAP_TILE_URL=${NEXT_PUBLIC_MAP_TILE_URL:-}" \
    --build-arg "NEXT_PUBLIC_MAP_TILE_ATTRIBUTION=${NEXT_PUBLIC_MAP_TILE_ATTRIBUTION:-}" \
    --build-arg "NEXT_PUBLIC_MAP_WMS_LAYERS=${NEXT_PUBLIC_MAP_WMS_LAYERS:-}" \
    --build-arg "NEXT_PUBLIC_MAP_WMS_FORMAT=${NEXT_PUBLIC_MAP_WMS_FORMAT:-}" \
    --build-arg "NEXT_PUBLIC_MAINTENANCE_MODE=${NEXT_PUBLIC_MAINTENANCE_MODE:-false}" \
    --build-arg "NEXT_PUBLIC_GOOGLE_CLIENT_ID=${NEXT_PUBLIC_GOOGLE_CLIENT_ID:-}" \
    .
)
docker push "$IMAGE"

echo "Done. Run sync-server-env.sh, copy server-files/ to VPS, run ./server-up.sh"
