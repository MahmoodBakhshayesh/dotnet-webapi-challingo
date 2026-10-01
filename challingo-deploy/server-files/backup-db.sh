#!/usr/bin/env bash
# Backup Postgres for this stack. Uses server-files/.env (synced from deploy/api.env).
# Usage: ./backup-db.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/load-env.sh"

BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
POSTGRES_CONTAINER="challingo-postgres"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
FILE="${BACKUP_DIR}/${POSTGRES_DB:-challingo}-${STAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

if ! docker ps --format '{{.Names}}' | grep -qx "$POSTGRES_CONTAINER"; then
  echo "ERROR: $POSTGRES_CONTAINER is not running. Run ./server-up.sh first." >&2
  exit 1
fi

echo "=== Backup $POSTGRES_DB -> $FILE ==="
docker exec "$POSTGRES_CONTAINER" pg_dump -U "${POSTGRES_USER:-scaffoldadmin}" "${POSTGRES_DB:-challingo}" \
  | gzip -9 > "$FILE"

echo "OK  $(du -h "$FILE" | awk '{print $1}')"

if [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] && (( RETENTION_DAYS > 0 )); then
  find "$BACKUP_DIR" -name '*.sql.gz' -type f -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
  echo "Pruned backups older than ${RETENTION_DAYS} days in $BACKUP_DIR"
fi

if [[ -n "${BACKUP_OFFSITE_PATH:-}" ]]; then
  mkdir -p "$BACKUP_OFFSITE_PATH"
  cp -f "$FILE" "${BACKUP_OFFSITE_PATH}/"
  echo "Copied to ${BACKUP_OFFSITE_PATH}/"
fi
