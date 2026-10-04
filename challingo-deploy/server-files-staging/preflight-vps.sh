#!/usr/bin/env bash
# VPS preflight — catch registry/TLS/redis/edge conflicts BEFORE server-up.
# Usage: ./preflight-vps.sh
# Exit 0 = safe to run server-up; non-zero = fix listed errors first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

fail=0
warn=0

ok()   { echo "OK    $*"; }
bad()  { echo "FAIL  $*" >&2; fail=1; }
note() { echo "WARN  $*" >&2; warn=1; }

is_truthy() {
  case "${1,,}" in true|1|yes|on) return 0 ;; *) return 1 ;; esac
}

echo "=== VPS preflight ($(hostname) / $SCRIPT_DIR) ==="

if [[ ! -f .env ]]; then
  bad "missing .env — sync from deploy (sync-server-env) and copy server-files to VPS"
  exit 1
fi

# shellcheck disable=SC1091
source "$SCRIPT_DIR/load-env.sh"

if ! command -v docker >/dev/null 2>&1; then
  bad "docker not installed — run GUI Server Setup → Docker"
else
  if docker info >/dev/null 2>&1; then
    ok "docker engine"
  else
    bad "docker installed but daemon not ready (systemctl start docker)"
  fi
fi

if ! docker compose version >/dev/null 2>&1; then
  bad "docker compose plugin missing"
else
  ok "docker compose"
fi

REGISTRY="${REGISTRY:-}"
REGISTRY_PORT="${REGISTRY##*:}"
REGISTRY_PORT="${REGISTRY_PORT:-}"
if [[ -z "$REGISTRY" ]]; then
  bad "REGISTRY empty in .env"
elif [[ "$REGISTRY_PORT" == "22" || "$REGISTRY_PORT" == "2222" ]]; then
  bad "REGISTRY=$REGISTRY looks like SSH — set REGISTRY=127.0.0.1:8443 (TLS) or :8585 (HTTP), re-sync, re-copy"
elif [[ "$REGISTRY_PORT" == "443" ]] && ss -lntp 2>/dev/null | grep -qE ':443\s.*nginx'; then
  bad "REGISTRY=$REGISTRY uses :443 but nginx owns HTTPS there — set REGISTRY=127.0.0.1:8443 + *_IMAGE lines, re-sync"
else
  ok "REGISTRY=$REGISTRY (port $REGISTRY_PORT)"
fi
# Image lines must match REGISTRY port (stale :443/ after registry moved to 8443)
if [[ -n "$REGISTRY_PORT" && "$REGISTRY_PORT" != "443" ]]; then
  if grep -qE '_IMAGE=.*:443/' .env 2>/dev/null; then
    bad "*_IMAGE= still points at :443/ while REGISTRY port is $REGISTRY_PORT — re-run sync-server-env / fix .env"
  fi
fi

USE_TLS=0
if is_truthy "${REGISTRY_TLS:-false}" || [[ "$REGISTRY_PORT" == "443" || "$REGISTRY_PORT" == "8443" ]]; then
  USE_TLS=1
fi

if [[ -n "$REGISTRY" && "$REGISTRY_PORT" != "22" && "$REGISTRY_PORT" != "2222" ]]; then
  if [[ "$USE_TLS" == "1" ]]; then
    code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 "https://${REGISTRY}/v2/" || echo 000)
    if [[ "$code" == "200" || "$code" == "401" ]]; then
      ok "registry TLS https://${REGISTRY}/v2/ → HTTP $code"
    else
      bad "registry TLS https://${REGISTRY}/v2/ → HTTP $code (install registry in GUI; open ufw $REGISTRY_PORT; Trust cert on Mac)"
    fi
    for d in "/etc/docker/certs.d/${REGISTRY}" "/etc/docker/certs.d/127.0.0.1:${REGISTRY_PORT}"; do
      if [[ -f "$d/ca.crt" ]]; then
        ok "docker trusts cert at $d/ca.crt"
      else
        note "missing $d/ca.crt — VPS pulls may fail until registry install trusts local cert"
      fi
    done
  else
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://${REGISTRY}/v2/" || echo 000)
    if [[ "$code" == "200" || "$code" == "401" ]]; then
      ok "registry HTTP http://${REGISTRY}/v2/ → HTTP $code"
    else
      bad "registry HTTP http://${REGISTRY}/v2/ → HTTP $code"
    fi
  fi
fi

# Image lines must use localhost registry, not public SSH host:22
for key in $(grep -E '^[A-Z0-9_]+_(API|WEB|WORKER)_IMAGE=' .env | cut -d= -f1 || true); do
  val=$(grep -E "^${key}=" .env | head -1 | cut -d= -f2- || true)
  if [[ "$val" == *':22/'* ]]; then
    bad "$key=$val contains :22/ — re-run sync-server-env (REGISTRY_HOST_PORT must be 8443/8585)"
  fi
done

if is_truthy "${Redis__Enabled:-false}"; then
  ok "Redis__Enabled=true (server-up will start redis profile first)"
  if [[ -z "${REDIS_PASSWORD:-}" || "${REDIS_PASSWORD}" == "changeme" ]]; then
    note "REDIS_PASSWORD empty/changeme — set a strong password in api.env before prod"
  fi
else
  ok "Redis disabled (in-memory fallbacks)"
fi

# Edge conflicts: Caddy + nginx both wanting :80 is fine only if Domain apply picks one path
caddy_up=0
nginx_up=0
docker ps --format '{{.Names}}' 2>/dev/null | grep -qx caddy && caddy_up=1
systemctl is-active --quiet nginx 2>/dev/null && nginx_up=1
if [[ "$caddy_up" == "1" && "$nginx_up" == "1" ]]; then
  note "both Docker Caddy and nginx are active — Domain apply will prefer Caddy; avoid binding nginx to :80"
elif [[ "$caddy_up" == "1" ]]; then
  ok "Docker Caddy owns public edge (Domain apply uses reverse_proxy)"
elif [[ "$nginx_up" == "1" ]]; then
  ok "nginx active for public edge"
else
  note "no nginx/Caddy yet — use scaffold-edge (:80/:81) or Apply domain after server-up"
fi

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi 'Status: active'; then
  if [[ "$USE_TLS" == "1" && -n "$REGISTRY_PORT" ]]; then
    if ufw status | grep -qE "${REGISTRY_PORT}/tcp.*ALLOW"; then
      ok "ufw allows ${REGISTRY_PORT}/tcp (registry)"
    else
      note "ufw active but ${REGISTRY_PORT}/tcp not clearly allowed — run: ufw allow ${REGISTRY_PORT}/tcp"
    fi
  fi
  ok "ufw present"
fi

# .env holds every secret: keep it private to the deploy user.
env_mode="$(stat -c '%a' .env 2>/dev/null || echo '')"
if [[ -n "$env_mode" && "${env_mode: -1}" != "0" ]]; then
  note ".env is readable by other users (mode $env_mode) — run: chmod 600 .env"
fi

# Sign-in codes: email goes API → RabbitMQ → Worker → SMTP; any gap means users never get a code.
if is_truthy "${Otp__DevMode:-false}"; then
  note "Otp__DevMode=true — sign-in codes are written to the logs; turn off in production"
fi
if is_truthy "${Otp__LogOnly:-false}" && { is_truthy "${Auth__EnableEmailAuth:-false}" || is_truthy "${Auth__EnablePhoneAuth:-false}"; }; then
  note "Otp__LogOnly=true — sign-in codes are created but never sent"
elif is_truthy "${Auth__EnableEmailAuth:-false}"; then
  is_truthy "${Email__Enabled:-false}" || note "email auth on but Email__Enabled=false — codes are not emailed"
  is_truthy "${RabbitMq__Enabled:-false}" || note "email auth on but RabbitMq__Enabled=false — the email queue is off"
  is_truthy "${Worker__EnableEmailDelivery:-false}" || note "Worker__EnableEmailDelivery=false — the Worker will not send email"
  for k in Email__SmtpHost Email__SmtpUsername Email__SmtpPassword Email__FromAddress; do
    [[ -n "${!k:-}" ]] || note "$k is empty — the Worker cannot send email"
  done
fi
if is_truthy "${RabbitMq__Enabled:-false}"; then
  if [[ "${RabbitMq__Password:-}" != "${RABBITMQ_PASSWORD:-}" || "${RabbitMq__UserName:-}" != "${RABBITMQ_USER:-}" ]]; then
    bad "RabbitMq__UserName/Password differ from RABBITMQ_USER/PASSWORD — the API and Worker cannot log in to the broker"
  else
    ok "RabbitMQ credentials consistent"
  fi
  case "${RABBITMQ_PASSWORD:-}" in ""|changeme|scaffold|guest) note "RABBITMQ_PASSWORD is a placeholder — set a strong value (only applied when the broker volume is first created)";; esac
fi
case "${POSTGRES_PASSWORD:-}" in ""|changeme|scaffold|postgres) note "POSTGRES_PASSWORD is a placeholder — change it with ALTER USER in the postgres container, then in api.env";; esac

for f in docker-compose.yml server-up-staging.sh health-check.sh; do
  if [[ -f "$f" ]]; then
    ok "present $f"
  else
    bad "missing $f"
  fi
done

echo ""
if [[ "$fail" -ne 0 ]]; then
  echo "Preflight FAILED — fix errors above, then re-run ./preflight-vps.sh" >&2
  exit 1
fi
if [[ "$warn" -ne 0 ]]; then
  echo "Preflight OK with warnings — review WARN lines, then ./server-up-staging.sh"
else
  echo "Preflight OK — safe to run ./server-up-staging.sh"
fi
exit 0
