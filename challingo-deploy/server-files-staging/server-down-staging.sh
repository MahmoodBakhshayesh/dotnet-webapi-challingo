#!/usr/bin/env bash
# Stop the staging compose stack (keeps volumes unless --volumes).
#
# Usage: ./server-down-staging.sh [--volumes]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/load-env.sh"

DOCKER_PREFIX="challingo"
NETWORK_NAME="${DOCKER_PREFIX}-staging-network"
WITH_VOLUMES=0

usage() {
  cat <<EOF
Usage: ./server-down-staging.sh [--volumes]

Stops staging postgres, api, web, worker.
  --volumes  Also remove staging named volumes (DB + uploads)
EOF
}

for arg in "$@"; do
  case "$arg" in
    --volumes|-v) WITH_VOLUMES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

echo "=== Stop ${DOCKER_PREFIX}-staging stack ==="
# Include optional profiles so their containers stop too.
args=(--profile messaging --profile redis down --remove-orphans)
if [[ "$WITH_VOLUMES" -eq 1 ]]; then
  echo "WARNING: removing staging volumes." >&2
  args+=(--volumes)
fi
docker compose "${args[@]}"

echo ""
echo "Staging stopped. Start again with ./server-up-staging.sh"
