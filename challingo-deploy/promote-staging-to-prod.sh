#!/usr/bin/env bash
# Promote the TAG currently configured for staging to production (:latest) and run server-up.
#
# Preferred VPS layout (project root = this script's directory, or parent of env folders):
#   challingo/production/   (or server-files/)
#   challingo/staging/      (or server-files-staging/)
#
# Usage (from project root on the VPS):
#   ./promote-staging-to-prod.sh           # uses API_VERSION from staging .env
#   ./promote-staging-to-prod.sh 1.2.3    # explicit TAG

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_dir() {
  local name="$1"
  shift
  local cand
  for cand in "$@"; do
    if [[ -d "$cand" ]]; then
      echo "$cand"
      return 0
    fi
  done
  return 1
}

PROD_DIR="$(resolve_dir production \
  "$SCRIPT_DIR/production" \
  "$SCRIPT_DIR/server-files" \
  "$SCRIPT_DIR/../production" \
  "$SCRIPT_DIR/../server-files" || true)"
STAG_DIR="$(resolve_dir staging \
  "$SCRIPT_DIR/staging" \
  "$SCRIPT_DIR/server-files-staging" \
  "$SCRIPT_DIR/../staging" \
  "$SCRIPT_DIR/../server-files-staging" || true)"

if [[ -z "${STAG_DIR:-}" || ! -f "$STAG_DIR/.env" ]]; then
  echo "Missing staging/.env (looked for staging/ and server-files-staging/)." >&2
  exit 1
fi
if [[ -z "${PROD_DIR:-}" || ! -d "$PROD_DIR" ]]; then
  echo "Missing production/ (looked for production/ and server-files/)." >&2
  exit 1
fi

STAGING_ENV="$STAG_DIR/.env"
PROD_ENV="$PROD_DIR/.env"

load_env_file() {
  local dir="$1"
  local envf="$2"
  if [[ -f "$dir/load-env.sh" ]]; then
    # shellcheck disable=SC1091
    source "$dir/load-env.sh" "$envf"
  else
    set -a
    # shellcheck disable=SC1090
    source "$envf"
    set +a
  fi
}

grep_env() {
  grep -E "^$1=" "$2" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r"' || true
}

image_from_env() {
  local kind="$1" envf="$2"
  local upper
  upper="$(echo "$kind" | tr '[:lower:]' '[:upper:]')"
  grep -Ei "^[A-Za-z0-9_]+_${upper}_IMAGE=" "$envf" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r"' || true
}

prefix_from_ref() {
  # 127.0.0.1:443/energyplatform-api:staging → energyplatform
  echo "$1" | sed -E 's|^.*/||; s|:.*||; s|-(api|web|worker)$||'
}

load_env_file "$STAG_DIR" "$STAGING_ENV"

TAG_ARG="${1:-}"
VERSION="${TAG_ARG:-${API_VERSION:-${TAG:-}}}"
if [[ -z "$VERSION" ]]; then
  echo "No TAG/API_VERSION — pass a version or sync staging env." >&2
  exit 1
fi

DOCKER_PREFIX="challingo"
# Prefer real image refs from .env over unsubstituted template / folder name
if [[ "$DOCKER_PREFIX" == *"PROJECT_DOCKER"* ]] || [[ -z "$DOCKER_PREFIX" ]]; then
  DOCKER_PREFIX="$(grep_env DOCKER_PREFIX "$PROD_ENV")"
fi
if [[ -z "$DOCKER_PREFIX" || "$DOCKER_PREFIX" == *"PROJECT_DOCKER"* ]]; then
  ref="$(image_from_env api "$STAGING_ENV")"
  [[ -z "$ref" ]] && ref="$(image_from_env api "$PROD_ENV")"
  [[ -n "$ref" ]] && DOCKER_PREFIX="$(prefix_from_ref "$ref")"
fi
if [[ -z "$DOCKER_PREFIX" || "$DOCKER_PREFIX" == *"PROJECT_DOCKER"* ]]; then
  echo "ERROR: could not resolve docker image prefix (set *_API_IMAGE in staging .env)" >&2
  exit 1
fi

REGISTRY_HOST="${REGISTRY:-$(grep_env REGISTRY "$PROD_ENV")}"
REGISTRY_HOST="${REGISTRY_HOST:-127.0.0.1:8585}"

# Remember previous production versions for rollback messaging
PREV_API_VERSION=""
PREV_WEB_VERSION=""
PREV_WORKER_VERSION=""
if [[ -f "$PROD_ENV" ]]; then
  load_env_file "$PROD_DIR" "$PROD_ENV" 2>/dev/null || true
  PREV_API_VERSION="${API_VERSION:-}"
  PREV_WEB_VERSION="${WEB_VERSION:-}"
  PREV_WORKER_VERSION="${WORKER_VERSION:-}"
  # Re-load staging after peeking at prod
  load_env_file "$STAG_DIR" "$STAGING_ENV"
fi

echo "PREV_API_VERSION=${PREV_API_VERSION}"
echo "PREV_WEB_VERSION=${PREV_WEB_VERSION}"
echo "PREV_WORKER_VERSION=${PREV_WORKER_VERSION}"
echo "DOCKER_PREFIX=${DOCKER_PREFIX} REGISTRY=${REGISTRY_HOST} VERSION=${VERSION}"

echo "=== Pre-promote DB backup ==="
if [[ -x "$PROD_DIR/backup-db.sh" ]] || [[ -f "$PROD_DIR/backup-db.sh" ]]; then
  (
    cd "$PROD_DIR"
    chmod +x backup-db.sh load-env.sh 2>/dev/null || true
    ./backup-db.sh
  )
else
  echo "WARNING: $PROD_DIR/backup-db.sh not found — continuing without backup." >&2
fi

resolve_src() {
  local kind="$1"
  local cand
  cand="$(image_from_env "$kind" "$STAGING_ENV")"
  if [[ -n "$cand" ]] && docker image inspect "$cand" >/dev/null 2>&1; then
    echo "$cand"
    return 0
  fi
  for cand in \
    "${REGISTRY_HOST}/${DOCKER_PREFIX}-${kind}:staging" \
    "${REGISTRY_HOST}/${DOCKER_PREFIX}-${kind}:${VERSION}" \
    "${DOCKER_PREFIX}-${kind}:staging" \
    "${DOCKER_PREFIX}-${kind}:${VERSION}"
  do
    if docker image inspect "$cand" >/dev/null 2>&1; then
      echo "$cand"
      return 0
    fi
  done
  cand="${REGISTRY_HOST}/${DOCKER_PREFIX}-${kind}:${VERSION}"
  if docker pull "$cand" 2>/dev/null; then
    echo "$cand"
    return 0
  fi
  cand="${REGISTRY_HOST}/${DOCKER_PREFIX}-${kind}:staging"
  echo "Falling back to ${cand}" >&2
  docker pull "$cand"
  echo "$cand"
}

echo "=== Promote ${VERSION} -> :latest (production) ==="
for kind in api web worker; do
  src="$(resolve_src "$kind")"
  dst="${REGISTRY_HOST}/${DOCKER_PREFIX}-${kind}:latest"
  docker tag "$src" "$dst"
  docker tag "$src" "${REGISTRY_HOST}/${DOCKER_PREFIX}-${kind}:${VERSION}" 2>/dev/null || true
  docker push "$dst" 2>/dev/null || echo "(push $dst skipped — using local tag)"
  echo "  ${kind}: ${src} -> ${dst}"
done

# Align production .env versions with the promoted TAG
if [[ -f "$PROD_ENV" ]]; then
  tmp="$(mktemp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    case "$line" in
      API_VERSION=*) echo "API_VERSION=$VERSION" ;;
      WEB_VERSION=*) echo "WEB_VERSION=$VERSION" ;;
      WORKER_VERSION=*) echo "WORKER_VERSION=$VERSION" ;;
      *) echo "$line" ;;
    esac
  done < "$PROD_ENV" > "$tmp"
  mv "$tmp" "$PROD_ENV"
fi

echo "=== Production server-up ==="
cd "$PROD_DIR"
chmod +x server-up.sh load-env.sh 2>/dev/null || true
./server-up.sh

load_env_file "$PROD_DIR" "$PROD_ENV"
API_PORT="${API_HOST_PORT:-8080}"
HEALTH_URL="http://127.0.0.1:${API_PORT}/health/ready"
READY_TIMEOUT_SEC="${PROMOTE_READY_TIMEOUT_SEC:-180}"
READY_INTERVAL_SEC=5

echo "=== Waiting for API ready (${HEALTH_URL}, timeout ${READY_TIMEOUT_SEC}s) ==="
elapsed=0
until curl -fsS "$HEALTH_URL" >/dev/null 2>&1; do
  if (( elapsed >= READY_TIMEOUT_SEC )); then
    echo "ERROR: API did not become ready within ${READY_TIMEOUT_SEC}s." >&2
    echo "Rollback hint: previous tags — API=${PREV_API_VERSION:-unknown} WEB=${PREV_WEB_VERSION:-unknown} WORKER=${PREV_WORKER_VERSION:-unknown}" >&2
    echo "  e.g. ./promote-staging-to-prod.sh ${PREV_API_VERSION:-<previous>}" >&2
    exit 1
  fi
  sleep "$READY_INTERVAL_SEC"
  elapsed=$((elapsed + READY_INTERVAL_SEC))
  echo "  ... waiting (${elapsed}s)"
done

echo ""
echo "Production is healthy on the same images testers validated on staging (tag ${VERSION})."
if [[ -n "${PREV_API_VERSION:-}" && "$PREV_API_VERSION" != "$VERSION" ]]; then
  echo "Previous API_VERSION was ${PREV_API_VERSION} (use that tag to roll back)."
fi
