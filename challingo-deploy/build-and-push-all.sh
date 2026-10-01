#!/usr/bin/env bash
# Build and push API, Web, and Worker images.
#
# Usage:
#   ./build-and-push-all.sh
#   ./build-and-push-all.sh --skip-worker

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKIP_WORKER=0

for arg in "$@"; do
  case "$arg" in
    --skip-worker) SKIP_WORKER=1 ;;
    -h|--help)
      echo "Usage: ./build-and-push-all.sh [--skip-worker]"
      exit 0
      ;;
  esac
done

echo "=== Build and push all (challingo) ==="

"$SCRIPT_DIR/build-and-push-api.sh"
"$SCRIPT_DIR/build-and-push-web.sh"

WORKER_DF="$SCRIPT_DIR/../challingo-api/Challingo.Worker/Dockerfile"
if [[ "$SKIP_WORKER" -eq 1 ]]; then
  echo "Skipping worker (--skip-worker)"
elif [[ -f "$WORKER_DF" ]]; then
  "$SCRIPT_DIR/build-and-push-worker.sh"
else
  echo "Skipping worker (no Dockerfile at $WORKER_DF)"
fi

echo ""
echo "All images pushed. Syncing server-files/.env + staging ..."
"$SCRIPT_DIR/sync-server-env.sh"
if [[ -f "$SCRIPT_DIR/sync-server-env-staging.sh" ]]; then
  "$SCRIPT_DIR/sync-server-env-staging.sh"
fi
echo ""
echo "Done. Copy server-files/ (and server-files-staging/) to VPS."
echo "  Staging: ./server-up-staging.sh  →  staging.{domain}/ or http://IP:81/"

echo "  Prod:    ./server-up.sh"
echo "  Promote: ./promote-staging-to-prod.sh"
