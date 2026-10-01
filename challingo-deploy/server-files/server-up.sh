#!/usr/bin/env bash
# VPS deploy script — runs docker compose for you (do not run compose manually).
#
# Steps:
#   1. docker compose up -d postgres
#   2. ensure registry (reuse existing at REGISTRY, or create project registry)
#   3. pull versioned images, promote to :latest
#   4. docker compose pull + up -d api + web + worker
#   5. docker compose ps
#
# Usage: ./server-up.sh

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
if is_truthy "${Observability__Enabled:-false}"; then
  COMPOSE_PROFILES+=("observability")
fi
if ((${#COMPOSE_PROFILES[@]} > 0)); then
  # Docker Compose expects a comma-separated list.
  export COMPOSE_PROFILES="$(IFS=,; echo "${COMPOSE_PROFILES[*]}")"
  echo "Compose profiles: $COMPOSE_PROFILES"
fi

_TEMPLATE_DOCKER="challingo"
API_SVC="challingo-api"
WEB_SVC="challingo-web"
WORKER_SVC="challingo-worker"
REGISTRY_CONTAINER="${_TEMPLATE_DOCKER}-registry"
# Prefer DOCKER_PREFIX from .env (sync writes it); fall back to template / *_API_IMAGE
if [[ -z "${DOCKER_PREFIX:-}" || "$DOCKER_PREFIX" == *"PROJECT_DOCKER"* ]]; then
  DOCKER_PREFIX="$_TEMPLATE_DOCKER"
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
  echo "ERROR: DOCKER_PREFIX unresolved — set DOCKER_PREFIX in .env or re-run sync-server-env" >&2
  exit 1
fi
REGISTRY_CONTAINER="${DOCKER_PREFIX}-registry"
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
POSTGRES_CONTAINER="${DOCKER_PREFIX}-postgres"
POSTGRES_UPSTREAM="postgres:16-alpine"
POSTGRES_IMAGE="${DOCKER_PREFIX}-postgres:16-alpine"

ensure_postgres_image() {
  if docker image inspect "$POSTGRES_IMAGE" >/dev/null 2>&1; then
    echo "Postgres image already present: ${POSTGRES_IMAGE}"
    return 0
  fi

  if docker image inspect "$POSTGRES_UPSTREAM" >/dev/null 2>&1; then
    echo "=== Tag postgres for ${DOCKER_PREFIX} (local ${POSTGRES_UPSTREAM} -> ${POSTGRES_IMAGE}) ==="
    docker tag "$POSTGRES_UPSTREAM" "$POSTGRES_IMAGE"
    return 0
  fi

  echo "=== Pull ${POSTGRES_UPSTREAM} then tag as ${POSTGRES_IMAGE} ==="
  if ! docker pull "$POSTGRES_UPSTREAM"; then
    echo "ERROR: Cannot pull ${POSTGRES_UPSTREAM} and no local copy found." >&2
    echo "On a machine with Docker Hub access:" >&2
    echo "  docker pull ${POSTGRES_UPSTREAM}" >&2
    echo "  docker save ${POSTGRES_UPSTREAM} | gzip > postgres-16-alpine.tar.gz" >&2
    echo "On this VPS:" >&2
    echo "  gunzip -c postgres-16-alpine.tar.gz | docker load" >&2
    echo "  ./server-up.sh" >&2
    exit 1
  fi
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
    echo "Removing orphaned container ${container} (not managed by this compose project)..."
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

registry_ready() {
  local code
  code=$("${CURL_REG[@]}" -o /dev/null -w '%{http_code}' "$REGISTRY_URL" || echo 000)
  [[ "$code" == "200" || "$code" == "401" ]]
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

registry_port_in_use() {
  if command -v ss >/dev/null 2>&1; then
    ss -tln | grep -q ":${REGISTRY_PORT}\$"
    return $?
  fi
  if command -v netstat >/dev/null 2>&1; then
    netstat -tln 2>/dev/null | grep -q ":${REGISTRY_PORT} "
    return $?
  fi
  return 1
}

wait_for_registry() {
  echo "=== Wait for registry at ${REGISTRY_URL} ==="
  for _ in $(seq 1 30); do
    if registry_ready; then
      return 0
    fi
    sleep 1
  done
  return 1
}

ensure_registry() {
  echo "=== Ensure registry ==="

  if [[ "$USE_REGISTRY_TLS" == "1" ]]; then
    trust_local_registry_cert
  fi
  registry_login

  if registry_ready; then
    echo "Using existing registry at ${REGISTRY_URL}"
    return 0
  fi

  # Shared scaffold-registry (TLS/auth) — do not invent a project HTTP registry on 443
  if docker ps --format '{{.Names}}' | grep -qx 'scaffold-registry'; then
    echo "scaffold-registry is running but ${REGISTRY_URL} is not ready." >&2
    echo "Check TLS/certs and REGISTRY in .env (current: ${REGISTRY})." >&2
    exit 1
  fi

  if docker ps -a --format '{{.Names}}' | grep -qx "$REGISTRY_CONTAINER"; then
    echo "Starting ${REGISTRY_CONTAINER}..."
    docker start "$REGISTRY_CONTAINER"
    if wait_for_registry; then
      return 0
    fi
    echo "Failed to start ${REGISTRY_CONTAINER}" >&2
    exit 1
  fi

  if registry_port_in_use; then
    echo "Port ${REGISTRY_PORT} is in use but no registry responds at ${REGISTRY_URL}" >&2
    echo "Another service may be bound to that port:" >&2
    docker ps --format 'table {{.Names}}\t{{.Ports}}' 2>/dev/null | grep "${REGISTRY_PORT}" || true
    echo "If you use the shared TLS registry, set REGISTRY=127.0.0.1:443 and REGISTRY_TLS=true in .env" >&2
    exit 1
  fi

  if [[ "$USE_REGISTRY_TLS" == "1" ]]; then
    echo "No registry at ${REGISTRY_URL}. Install it from GUI: Remote VPS → Docker registry." >&2
    exit 1
  fi

  echo "No registry found — creating ${REGISTRY_CONTAINER} on port ${REGISTRY_PORT}..."
  docker compose --profile registry up -d registry
  if ! wait_for_registry; then
    echo "Registry not ready at ${REGISTRY_URL}" >&2
    exit 1
  fi
}

echo "=== Start postgres ==="
ensure_postgres_image
compose_up postgres "$POSTGRES_CONTAINER"

ensure_registry

promote() {
  local kind="$1" version="$2"
  local src="${REGISTRY}/${DOCKER_PREFIX}-${kind}:${version}"
  local dst="${REGISTRY}/${DOCKER_PREFIX}-${kind}:latest"
  echo "=== Pull ${kind} ${version} and promote -> latest ==="
  docker pull "$src"
  docker tag "$src" "$dst"
  docker push "$dst"
}

DEPLOY_SERVICES=("$API_SVC" "$WEB_SVC" "$WORKER_SVC")

if [[ -n "${API_VERSION:-}" ]]; then promote api "$API_VERSION"; fi
if [[ -n "${WEB_VERSION:-}" ]]; then promote web "$WEB_VERSION"; fi
if [[ -n "${WORKER_VERSION:-}" ]]; then promote worker "$WORKER_VERSION"; fi

echo "=== Pull and deploy api + web + worker ==="
docker compose pull "${DEPLOY_SERVICES[@]}"
for svc in "${DEPLOY_SERVICES[@]}"; do
  remove_orphan_if_not_managed "$svc" "$svc"
done
docker compose up -d --force-recreate "${DEPLOY_SERVICES[@]}"

echo ""
docker compose ps
echo ""
echo "Optional: ./health-check.sh  ./backup-db.sh  ./server-down.sh"
