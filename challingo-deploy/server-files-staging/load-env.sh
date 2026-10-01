#!/usr/bin/env bash
# Parse KEY=VALUE env file (safe for spaces; no shell eval). Usage: source load-env.sh [path]

_env_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_env_file="${1:-$_env_dir/.env}"

if [[ ! -f "$_env_file" ]]; then
  echo "Missing $_env_file" >&2
  return 1 2>/dev/null || exit 1
fi

_load_env_strip_quotes() {
  local v="$1"
  local n=${#v}
  if (( n >= 2 )); then
    if [[ ${v:0:1} == '"' && ${v:n-1:1} == '"' ]]; then
      v="${v:1:n-2}"
      v="$(printf '%s' "$v" | sed 's/\\"/"/g')"
    elif [[ ${v:0:1} == "'" && ${v:n-1:1} == "'" ]]; then
      v="${v:1:n-2}"
    fi
  fi
  printf '%s' "$v"
}

set -a
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line//$'\r'/}"
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^([^=[:space:]]+)=(.*)$ ]] || continue
  key="${BASH_REMATCH[1]}"
  val="$(_load_env_strip_quotes "${BASH_REMATCH[2]}")"
  export "$key"="$val"
done < "$_env_file"
set +a
