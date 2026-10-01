#!/usr/bin/env bash
# Sync server-files-staging/.env (wrapper → sync-server-env-staging.ps1).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SCAFFOLD_ROOT=""
if [[ -f "$ROOT/.scaffold-root" ]]; then
  SCAFFOLD_ROOT="$(tr -d '\r\n' < "$ROOT/.scaffold-root")"
fi
RUNNER="$ROOT/../scripts/lib/run-pwsh.sh"
if [[ -n "$SCAFFOLD_ROOT" && -f "$SCAFFOLD_ROOT/scripts/lib/run-pwsh.sh" ]]; then
  RUNNER="$SCAFFOLD_ROOT/scripts/lib/run-pwsh.sh"
elif [[ -f "$ROOT/../../scripts/lib/run-pwsh.sh" ]]; then
  RUNNER="$(cd "$ROOT/../.." && pwd)/scripts/lib/run-pwsh.sh"
fi
if [[ ! -f "$RUNNER" ]]; then
  if command -v pwsh >/dev/null 2>&1; then
    exec pwsh -NoProfile -ExecutionPolicy Bypass -File "$ROOT/sync-server-env-staging.ps1" "$@"
  fi
  if command -v powershell >/dev/null 2>&1; then
    exec powershell -NoProfile -ExecutionPolicy Bypass -File "$ROOT/sync-server-env-staging.ps1" "$@"
  fi
  echo "PowerShell Core (pwsh) is required to run sync-server-env-staging.ps1" >&2
  exit 1
fi
exec "$RUNNER" "$ROOT/sync-server-env-staging.ps1" "$@"
