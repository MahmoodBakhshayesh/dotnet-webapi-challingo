#!/usr/bin/env bash
# VPS: stop the challingo compose stack (containers + project network).
# Named volumes (postgres data, uploads, registry) are kept unless you pass --volumes.
#
# Usage: ./server-down.sh [--volumes]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/load-env.sh"

DOCKER_PREFIX="challingo"
NETWORK_NAME="${DOCKER_PREFIX}-network"
WITH_VOLUMES=0

usage() {
  cat <<EOF
Usage: ./server-down.sh [--volumes]

Stops postgres, api, web, worker, and project registry (if running).
Removes containers and network ${NETWORK_NAME}.

  --volumes  Also remove named volumes (postgres data, uploads, registry)
EOF
}

for arg in "$@"; do
  case "$arg" in
    --volumes|-v) WITH_VOLUMES=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

echo "=== Stop ${DOCKER_PREFIX} stack ==="

# Include optional profiles so their containers stop too.
args=(--profile registry --profile messaging --profile redis --profile observability down --remove-orphans)
if [[ "$WITH_VOLUMES" -eq 1 ]]; then
  echo "WARNING: removing named volumes (postgres data, uploads, registry)." >&2
  args+=(--volumes)
fi

docker compose "${args[@]}"

echo ""
if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  echo "Network ${NETWORK_NAME} still exists (another container may be attached)." >&2
else
  echo "Network ${NETWORK_NAME} removed."
fi

echo ""
echo "Stack stopped. Start again with ./server-up.sh"
