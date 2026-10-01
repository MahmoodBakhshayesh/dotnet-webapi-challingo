#!/usr/bin/env bash
# VPS: health check after server-up.sh (HTTP readiness + core services)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/load-env.sh"

API_PORT="${API_HOST_PORT:-8080}"
WEB_PORT="${WEB_HOST_PORT:-3000}"

check() {
  local name="$1" url="$2"
  if curl -sf --max-time 5 "$url" >/dev/null; then
    echo "OK  $name ($url)"
  else
    echo "FAIL $name ($url)" >&2
    return 1
  fi
}

echo "=== Health check ==="
fail=0
reg="${REGISTRY:-127.0.0.1:8585}"
reg_port="${reg##*:}"
use_tls=0
case "${REGISTRY_TLS:-}" in 1|true|yes|on) use_tls=1 ;; esac
[[ "$reg_port" == "443" ]] && use_tls=1
if [[ "$use_tls" == "1" ]]; then
  code=$(curl -sk -o /dev/null -w '%{http_code}' "https://${reg}/v2/" || echo 000)
  if [[ "$code" == "200" || "$code" == "401" ]]; then
    echo "OK  registry (https://${reg}/v2/ HTTP $code)"
  else
    echo "FAIL registry (https://${reg}/v2/ HTTP $code)" >&2
    fail=1
  fi
else
  check "registry" "http://${reg}/v2/" || fail=1
fi
check "api-live" "http://127.0.0.1:${API_PORT}/health/live" \
  || check "api-swagger" "http://127.0.0.1:${API_PORT}/swagger/index.html" || fail=1
check "api-ready" "http://127.0.0.1:${API_PORT}/health/ready" || fail=1
check "web" "http://127.0.0.1:${WEB_PORT}/" || fail=1

WORKER_CONTAINER="challingo-worker"
if docker ps --format '{{.Names}}' | grep -qx "$WORKER_CONTAINER"; then
  if docker inspect -f '{{.State.Running}}' "$WORKER_CONTAINER" 2>/dev/null | grep -qx true; then
    echo "OK  worker ($WORKER_CONTAINER running)"
  else
    echo "FAIL worker ($WORKER_CONTAINER not running)" >&2
    fail=1
  fi
else
  echo "FAIL worker ($WORKER_CONTAINER not deployed)" >&2
  fail=1
fi

docker compose ps
exit $fail
