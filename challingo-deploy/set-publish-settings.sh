#!/usr/bin/env bash
# Interactive publish settings (domain, ports, nginx, REGISTRY, TAG).
# Example: ./set-publish-settings.sh -Interactive
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
  # Running from templates/deploy-template inside the toolkit
  RUNNER="$(cd "$ROOT/../.." && pwd)/scripts/lib/run-pwsh.sh"
fi
if [[ ! -f "$RUNNER" ]]; then
  # Generated project: require pwsh directly
  if command -v pwsh >/dev/null 2>&1; then
    exec pwsh -NoProfile -ExecutionPolicy Bypass -File "$ROOT/Set-PublishSettings.ps1" "$@"
  fi
  if command -v powershell >/dev/null 2>&1; then
    exec powershell -NoProfile -ExecutionPolicy Bypass -File "$ROOT/Set-PublishSettings.ps1" "$@"
  fi
  echo "PowerShell Core (pwsh) is required to run Set-PublishSettings.ps1" >&2
  echo "  brew install --cask powershell" >&2
  exit 1
fi
exec "$RUNNER" "$ROOT/Set-PublishSettings.ps1" "$@"
