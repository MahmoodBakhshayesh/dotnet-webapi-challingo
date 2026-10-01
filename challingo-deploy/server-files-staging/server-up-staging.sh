#!/usr/bin/env bash
# Staging twin stack (isolated DB). Public: staging hostname or edge :81 (not /_staging path).
# Registry must already exist (from prod server-up / GUI registry install).
#
# Usage: ./server-up-staging.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/load-env.sh"

is_truthy() {
  case "${1,,}" in true|1|yes|on) return 0 ;; *) return 1 ;; esac
}

COMPOSE_PROFILES=()
if is_truthy "${RabbitMq__Enabled:-false}"; then
  COMPOSE_PROFILES+=("messaging")
fi
if is_truthy "${Redis__Enabled:-false}"; then
  COMPOSE_PROFILES+=("redis")
fi
if ((${#COMPOSE_PROFILES[@]} > 0)); then
  # Docker Compose expects a comma-separated list.
  export COMPOSE_PROFILES="$(IFS=,; echo "${COMPOSE_PROFILES[*]}")"
  echo "Compose profiles: $COMPOSE_PROFILES"
fi

DOCKER_PREFIX="challingo"
API_SVC="challingo-api"
WEB_SVC="challingo-web"
WORKER_SVC="challingo-worker"
API_CONTAINER="challingo-staging-api"
WEB_CONTAINER="challingo-staging-web"
WORKER_CONTAINER="challingo-staging-worker"
POSTGRES_CONTAINER="${DOCKER_PREFIX}-staging-postgres"
POSTGRES_UPSTREAM="postgres:16-alpine"
POSTGRES_IMAGE="${DOCKER_PREFIX}-postgres:16-alpine"

# Prefer DOCKER_PREFIX from .env / *_API_IMAGE when template token was not substituted
_TEMPLATE_DOCKER="$DOCKER_PREFIX"
if [[ -z "${DOCKER_PREFIX:-}" || "$DOCKER_PREFIX" == *"PROJECT_DOCKER"* ]]; then
  # reload from env after source (load-env already ran above)
  if [[ -n "${DOCKER_PREFIX:-}" && "$DOCKER_PREFIX" != *"PROJECT_DOCKER"* ]]; then
    :
  else
    DOCKER_PREFIX="$_TEMPLATE_DOCKER"
  fi
fi
# Re-read: source may have set DOCKER_PREFIX before this assignment overwrote it — check .env
_env_prefix="$(grep -E '^DOCKER_PREFIX=' .env 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r"' || true)"
if [[ -n "$_env_prefix" && "$_env_prefix" != *"PROJECT_DOCKER"* ]]; then
  DOCKER_PREFIX="$_env_prefix"
fi
if [[ -z "${DOCKER_PREFIX}" || "$DOCKER_PREFIX" == *"PROJECT_DOCKER"* ]]; then
  _img=""
  for _k in $(compgen -e 2>/dev/null | grep -E '_API_IMAGE$' || true); do
    _img="${!_k}"
    [[ -n "$_img" ]] && break
  done
  if [[ -n "$_img" ]]; then
    DOCKER_PREFIX="$(echo "$_img" | sed -E 's|^.*/||; s|:.*||; s|-api$||')"
  fi
fi
if [[ -z "${DOCKER_PREFIX}" || "$DOCKER_PREFIX" == *"PROJECT_DOCKER"* ]]; then
  echo "ERROR: DOCKER_PREFIX unresolved — set DOCKER_PREFIX in .env or re-run sync-server-env-staging" >&2
  exit 1
fi
POSTGRES_CONTAINER="${DOCKER_PREFIX}-staging-postgres"
POSTGRES_IMAGE="${DOCKER_PREFIX}-postgres:16-alpine"

REGISTRY="${REGISTRY:-127.0.0.1:8585}"
REGISTRY_PORT="${REGISTRY##*:}"
REGISTRY_PORT="${REGISTRY_PORT:-8585}"
USE_REGISTRY_TLS=0
if is_truthy "${REGISTRY_TLS:-false}" || [[ "$REGISTRY_PORT" == "443" ]]; then
  USE_REGISTRY_TLS=1
fi
if [[ "$USE_REGISTRY_TLS" == "1" ]]; then
  REGISTRY_URL="https://${REGISTRY}/v2/"
  CURL_REG=(curl -sk)
else
  REGISTRY_URL="http://${REGISTRY}/v2/"
  CURL_REG=(curl -s)
fi

ensure_postgres_image() {
  if docker image inspect "$POSTGRES_IMAGE" >/dev/null 2>&1; then
    echo "Postgres image already present: ${POSTGRES_IMAGE}"
    return 0
  fi
  if docker image inspect "$POSTGRES_UPSTREAM" >/dev/null 2>&1; then
    docker tag "$POSTGRES_UPSTREAM" "$POSTGRES_IMAGE"
    return 0
  fi
  echo "=== Pull ${POSTGRES_UPSTREAM} then tag as ${POSTGRES_IMAGE} ==="
  docker pull "$POSTGRES_UPSTREAM"
  docker tag "$POSTGRES_UPSTREAM" "$POSTGRES_IMAGE"
}

remove_orphan_if_not_managed() {
  local service="$1"
  local container="$2"
  local managed
  managed=$(docker compose ps -q "$service" 2>/dev/null || true)
  if [[ -n "$managed" ]]; then
    return 0
  fi
  if docker ps -aq -f "name=^/${container}$" | grep -q .; then
    echo "Removing orphaned container ${container}..."
    docker rm -f "$container"
  fi
}

compose_up() {
  local service="$1"
  local container="${2:-}"
  if [[ -n "$container" ]]; then
    remove_orphan_if_not_managed "$service" "$container"
  fi
  docker compose up -d "$service"
}

trust_local_registry_cert() {
  local crt="/opt/registry/certs/domain.crt"
  [[ -f "$crt" ]] || return 0
  local dests=("/etc/docker/certs.d/${REGISTRY}" "/etc/docker/certs.d/127.0.0.1:${REGISTRY_PORT}")
  if [[ "$REGISTRY_PORT" == "443" ]]; then
    dests+=("/etc/docker/certs.d/127.0.0.1")
  fi
  local d
  for d in "${dests[@]}"; do
    mkdir -p "$d"
    cp "$crt" "$d/ca.crt"
  done
}

registry_login() {
  if [[ -n "${REGISTRY_USER:-}" && -n "${REGISTRY_PASSWORD:-}" ]]; then
    echo "=== docker login ${REGISTRY} ==="
    echo "$REGISTRY_PASSWORD" | docker login "$REGISTRY" -u "$REGISTRY_USER" --password-stdin
  fi
}

registry_ready() {
  local code
  code=$("${CURL_REG[@]}" -o /dev/null -w '%{http_code}' "$REGISTRY_URL" || echo 000)
  # 200 = open registry, 401 = auth required but process is up
  [[ "$code" == "200" || "$code" == "401" ]]
}

if [[ "$USE_REGISTRY_TLS" == "1" ]]; then
  trust_local_registry_cert
fi
registry_login

if ! registry_ready; then
  echo "ERROR: Registry not reachable at ${REGISTRY_URL}" >&2
  echo "Install/check the shared registry in GUI: Remote VPS → Docker registry." >&2
  echo "Or fix REGISTRY in .env (current: ${REGISTRY}). For TLS use port 443 and https." >&2
  docker ps --filter name=scaffold-registry --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
  exit 1
fi
echo "Using existing registry at ${REGISTRY_URL}"

promote_staging() {
  local kind="$1" version="$2"
  local src="${REGISTRY}/${DOCKER_PREFIX}-${kind}:${version}"
  local dst="${REGISTRY}/${DOCKER_PREFIX}-${kind}:staging"
  echo "=== Pull ${kind} ${version} and promote -> staging ==="
  docker pull "$src"
  docker tag "$src" "$dst"
  docker push "$dst"
}

echo "=== Start staging postgres ==="
ensure_postgres_image
compose_up postgres "$POSTGRES_CONTAINER"

if [[ -n "${API_VERSION:-}" ]]; then promote_staging api "$API_VERSION"; fi
if [[ -n "${WEB_VERSION:-}" ]]; then promote_staging web "$WEB_VERSION"; fi
if [[ -n "${WORKER_VERSION:-}" ]]; then promote_staging worker "$WORKER_VERSION"; fi

echo "=== Pull and deploy staging api + web + worker ==="
docker compose pull "$API_SVC" "$WEB_SVC" "$WORKER_SVC"
remove_orphan_if_not_managed "$API_SVC" "$API_CONTAINER"
remove_orphan_if_not_managed "$WEB_SVC" "$WEB_CONTAINER"
remove_orphan_if_not_managed "$WORKER_SVC" "$WORKER_CONTAINER"
docker compose up -d --force-recreate "$API_SVC" "$WEB_SVC" "$WORKER_SVC"

echo ""
docker compose ps
echo ""
echo "Staging public URLs: staging.{domain}/  or  http://VPS_IP:81/  (edge) — not /_staging"
echo "After QA, promote same TAG to production:"
echo "  cd .. && chmod +x promote-staging-to-prod.sh && ./promote-staging-to-prod.sh"
