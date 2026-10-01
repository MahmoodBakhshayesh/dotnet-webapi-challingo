#!/usr/bin/env bash
# Source a KEY=VALUE env file. Usage: source load-env.sh [path]

_load_env_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_load_env_file="${1:-${DEPLOY_ENV_FILE:-$_load_env_dir/.env}}"

if [[ ! -f "$_load_env_file" ]]; then
  echo "Missing env file: $_load_env_file" >&2
  return 1 2>/dev/null || exit 1
fi

set -a
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line//$'\r'/}"
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^([^=[:space:]]+)=(.*)$ ]] || continue
  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"
  # Peel stacked quotes from GUI/sync remangles (passwords containing #).
  if command -v python3 >/dev/null 2>&1; then
    val="$(OUT_VAL="$val" python3 - <<'PY'
import os
v = os.environ.get("OUT_VAL", "")
def once(x: str) -> str:
    x = x.strip()
    if len(x) >= 2 and x[0] == '"' and x[-1] == '"':
        inner, out, i = x[1:-1], [], 0
        while i < len(inner):
            if inner[i] == "\\" and i + 1 < len(inner) and inner[i + 1] in '"\\':
                out.append(inner[i + 1]); i += 2; continue
            out.append(inner[i]); i += 1
        return "".join(out)
    if len(x) >= 2 and x[0] == "'" and x[-1] == "'":
        return x[1:-1]
    return x
for _ in range(40):
    n = once(v)
    if n == v: break
    v = n
print(v, end="")
PY
)"
  else
    for _ in $(seq 1 20); do
      n=${#val}
      (( n >= 2 )) || break
      if [[ ${val:0:1} == '"' && ${val:n-1:1} == '"' ]]; then
        val="${val:1:n-2}"
        val="${val//\\\"/\"}"
        val="${val//\\\\/\\}"
      elif [[ ${val:0:1} == "'" && ${val:n-1:1} == "'" ]]; then
        val="${val:1:n-2}"
      else
        break
      fi
    done
  fi
  export "$key"="$val"
done < "$_load_env_file"
set +a

test_registry() {
  local reg="${1:-$REGISTRY}"
  local hostport="${reg#http://}"
  hostport="${hostport#https://}"
  hostport="${hostport%%/*}"
  local uri="http://${hostport}/v2/"
  echo "Checking $uri ..."
  if curl -sf --max-time 8 "$uri" >/dev/null; then
    return 0
  fi
  if curl -s --max-time 8 -o /dev/null -w '%{http_code}' "$uri" 2>/dev/null | grep -q '^401$'; then
    echo "Registry OK at $uri (401 without auth is expected)"
    return 0
  fi
  echo "Registry not responding at $uri" >&2
  if nc -z "${hostport%%:*}" "${hostport##*:}" 2>/dev/null; then
    echo "  TCP port is open but HTTP did not respond (registry uses plain HTTP, not HTTPS)." >&2
    echo "  On VPS: curl -s http://127.0.0.1:8585/v2/  and  docker ps | grep registry" >&2
    echo "  If local curl works, open firewall: sudo ufw allow 8585/tcp" >&2
    echo "  Or push via SSH tunnel: ssh -L 8585:127.0.0.1:8585 user@VPS  then REGISTRY=127.0.0.1:8585" >&2
  else
    echo "  Check firewall, registry container, and that $hostport is correct." >&2
  fi
  exit 1
}

assert_insecure_registry() {
  local reg="${1:-$REGISTRY}"
  local hostport="${reg#http://}"
  hostport="${hostport#https://}"
  hostport="${hostport%%/*}"
  if [[ "$hostport" =~ ^127\.|^localhost|^::1 ]]; then
    return 0
  fi
  if docker info 2>/dev/null | grep -q "Insecure Registries" && docker info 2>/dev/null | grep -q "$hostport"; then
    return 0
  fi
  echo "Add $hostport to Docker insecure-registries before push." >&2
  exit 1
}

ensure_buildx() {
  local builder="${1:-challingo-builder}"
  if docker buildx use desktop-linux >/dev/null 2>&1; then
    :
  elif docker buildx use default >/dev/null 2>&1; then
    :
  elif docker buildx inspect "$builder" >/dev/null 2>&1; then
    docker buildx use "$builder" >/dev/null
  else
    docker buildx create --name "$builder" --use
  fi
  docker buildx inspect --bootstrap >/dev/null
}
