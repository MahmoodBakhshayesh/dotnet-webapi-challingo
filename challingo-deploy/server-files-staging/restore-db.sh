#!/usr/bin/env bash
# Restore Postgres from a .sql.gz produced by backup-db.sh
# Usage: ./restore-db.sh ./backups/mydb-20260101-120000.sql.gz

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <backup.sql.gz>" >&2
  exit 1
fi

BACKUP_FILE="$1"
if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "File not found: $BACKUP_FILE" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/load-env.sh"

POSTGRES_CONTAINER="challingo-postgres"

echo "WARNING: This will overwrite database ${POSTGRES_DB} in ${POSTGRES_CONTAINER}."
read -r -p "Type yes to continue: " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

echo "=== Restore from $BACKUP_FILE ==="
gunzip -c "$BACKUP_FILE" | docker exec -i "$POSTGRES_CONTAINER" \
  psql -U "${POSTGRES_USER:-scaffoldadmin}" -d "${POSTGRES_DB:-challingo}"

echo "Done."
