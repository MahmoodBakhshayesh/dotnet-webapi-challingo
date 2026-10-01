# Deploy — Challingo

| Start here | Language |
|------------|----------|
| **[QUICK-START.md](./QUICK-START.md)** | English cheat sheet — daily commands |
| **[QUICK-START.fa.md](./QUICK-START.fa.md)** | Persian cheat sheet |
| **[SETUP-GUIDE.md](./SETUP-GUIDE.md)** | Full setup, env examples, troubleshooting |

This README covers deploy scripts, compose layout, and reference detail.

---

## Overview

```
Dev machine                          VPS (server-files/)
────────────                         ───────────────────
api.env  ──┐
web.env  ──┼─ sync-server-env.ps1 ──► docker-compose.yml
           │                         server-up.sh  ← you run this (not compose manually)
           │                         server-down.sh ← stop stack + remove network
           │                         docker compose reads server-files/.env
build-and-push-api.ps1 ──push──►     registry :8585  (shared OK)
build-and-push-web.ps1               postgres, api, web, worker containers
build-and-push-worker.ps1
build-and-push-all.ps1               api + web + worker in one run
```

- **Dev** builds images and pushes **versioned tags** (e.g. `1.0.0`) to the registry.
- **VPS** runs **`./server-up.sh`**, which calls **`docker compose`** for you — you do not run `docker compose up -d` yourself for releases.
- Compose runs **`:latest`** tags; `server-up.sh` promotes `1.0.0` → `:latest` before starting api, web, and worker.

---

## Prerequisites

### Dev machine

- Docker Desktop (or Docker + buildx)
- PowerShell **or** bash (macOS/Linux: install `pwsh` — `brew install --cask powershell`)
- **One-time:** if push `REGISTRY` is a remote IP, add it to Docker **insecure-registries** (Settings → Docker Engine):

```json
"insecure-registries": ["YOUR_VPS_IP:8585"]
```

Apply & Restart. Private registries use HTTP only.

### VPS (Linux)

- Docker + Docker Compose plugin (`docker compose`)
- `curl`
- Copy the entire **`challingo-deploy/server-files/`** folder to the server
- **One-time:** add localhost registry to `/etc/docker/daemon.json` (registry uses HTTP):

```json
{
  "insecure-registries": ["127.0.0.1:8585"]
}
```

Then `sudo systemctl restart docker`. `sync-server-env` sets `REGISTRY=127.0.0.1:8585` on the server (host port **8585** maps to registry container port **5000**).

---

## Configuration files

| File | Where | Purpose |
|------|-------|---------|
| `api.env` | Dev | `TAG`, push `REGISTRY`, host ports, Postgres, JWT, appsettings (`Section__Key=...`), **`Worker__*`**, **`RateLimit__*` / `RequestTimeout__*` / `Http__*` / `Idempotency__*`** |
| `web.env` | Dev | `TAG`, push `REGISTRY`, `WEB_HOST_PORT`, `NEXT_PUBLIC_*` (baked into web image at build) |
| `sync-server-env.ps1` / `.sh` | Dev | Merges `api.env` + `web.env` → `server-files/.env` |
| `sync-server-env-staging.ps1` / `.sh` | Dev | Same merge → `server-files-staging/.env` (ports/DB offset, `:staging` tags) |
| `promote-staging-to-prod.sh` | VPS | Promote verified `TAG` → `:latest` and run prod `server-up` |
| `server-files/.env` | VPS | Runtime config; **`REGISTRY=127.0.0.1:8585`** for local pull (dev push uses public IP in `api.env`) |
| `server-files/docker-compose.yml` | VPS | Stack definition (postgres, api, web, worker; optional registry profile) |
| `server-files/server-up.sh` | VPS | **Main deploy command** — runs compose + pull/promote |
| `server-files/server-down.sh` | VPS | Stop stack and remove project network (keeps volumes) |
| `server-files-staging/` | VPS | Twin stack on staging hostname / edge :81 (isolated DB) |

### Appsettings via env

Use double underscore for nested JSON keys (ASP.NET Core convention):

```env
ConnectionStrings__Database=Host=postgres;Port=5432;Database=challingo;...
Jwt__Key=your-secret-at-least-32-chars
Cors__AllowedOrigins__0=http://127.0.0.1:3000
Store__Currency=USD
```

### Auth (email + phone OTP)

Feature flags in `api.env`:

```env
Auth__EnablePasswordLogin=true
Auth__EnableEmailAuth=true
Auth__EnablePhoneAuth=true
```

| Endpoint | Purpose |
|----------|---------|
| `POST /api/auth/register/email` | Email signup — sends OTP |
| `POST /api/auth/register/email/confirm` | Confirm signup + JWT |
| `POST /api/auth/otp/request` | Email login OTP |
| `POST /api/auth/otp/verify` | Email login confirm |
| `POST /api/auth/check-phone` | Phone exists / registration hint |
| `POST /api/auth/register` | Phone signup OTP |
| `POST /api/auth/register/confirm` | Phone signup confirm |
| `POST /api/auth/login/otp/request` | Phone login OTP |
| `POST /api/auth/login/otp/confirm` | Phone login confirm |

### RabbitMQ + worker OTP/email delivery

`docker-compose.yml` includes a **rabbitmq** service. OTP SMS and email are **queued by the API** and **sent by the worker** (off by default).

**Local dev:** `Otp__DevMode=true`, `Otp__LogOnly=true` — codes print to API logs; no queue send.

**Production:**

```env
RabbitMq__Enabled=true
RabbitMq__HostName=rabbitmq
Otp__DevMode=false
Otp__LogOnly=false
Worker__EnableSmsOtpDelivery=true
Worker__EnableEmailDelivery=true
Email__Enabled=true
Sms__Provider=SmsIr
```

| Setting | Purpose |
|---------|---------|
| `RabbitMq__Enabled` | API publishes to queues; worker consumes |
| `Worker__EnableSmsOtpDelivery` | Worker SMS OTP consumer |
| `Worker__EnableEmailDelivery` | Worker SMTP consumer |
| `Email__Enabled` | Allow OTP/notification email send |
| `Sms__SmsIrApiKey` | sms.ir API key (worker sends) |
| `Otp__LogOnly` | `true` = no queue publish after OTP stored |

Management UI: `http://127.0.0.1:15672` (default user/password from `RABBITMQ_USER` / `RABBITMQ_PASSWORD` in `api.env`).

### Platform defaults (api.env → sync → server)

All toggles live in **`api.env`** (single source). `sync-server-env.ps1` copies them to `server-files/.env`.

| Area | Keys | Default |
|------|------|---------|
| Logging | `Serilog__Enabled`, `Serilog__MinimumLevel`, `Serilog__WriteToFile` | on, Information, off |
| Health HTTP | `Health__Enabled` | on → `/health/live`, `/health/ready` |
| Migrations | `Database__AutoMigrate` | `false` in `api.env`; **`sync-server-env` forces `true` on VPS `.env`** |
| Maintenance | `Maintenance__Enabled`, `Maintenance__BypassKey` | off |
| Web maintenance | `NEXT_PUBLIC_MAINTENANCE_MODE` in **web.env** | off (rebuild web after change) |
| OTP / auth rate limit | `Auth__OtpRateLimitPerMinute`, `Otp__MaxVerifyAttempts` | 10 / 5 |
| Global rate limit | `RateLimit__Enabled`, `RateLimit__GlobalPerMinute` | on, 120/min |
| Request timeout | `RequestTimeout__Enabled`, `RequestTimeout__Seconds` | on, 30s |
| Outbound HTTP resilience | `Http__Enabled`, `Http__TimeoutSeconds`, `Http__RetryCount`, … | on (SMS HttpClient) |
| Idempotency-Key | `Idempotency__Enabled`, `Idempotency__TtlHours`, `Idempotency__HeaderName` | **off**, 24h |
| Backups | `BACKUP_DIR`, `BACKUP_RETENTION_DAYS`, `BACKUP_OFFSITE_PATH` | `./backups`, 14 days |
| Observability | `Observability__Enabled`, `SEQ_HOST_PORT`, `UPTIME_KUMA_HOST_PORT` | off |
| Rabbit profile | `RabbitMq__Enabled` | off → `server-up.sh` skips `messaging` profile |

**VPS scripts** (in `server-files/`):

- `./health-check.sh` — readiness + web + worker
- `./backup-db.sh` — `pg_dump` gzip to `BACKUP_DIR`
- `./restore-db.sh <file.sql.gz>` — destructive restore

**Web:** `npm run generate-api-client` (API must be running; OpenAPI → `src/lib/api-schema.ts`).

**CI:** `New-Project.ps1` adds `.github/workflows/ci.yml` (build api, web, worker).

Inside Docker, Postgres host is **`postgres`** (service name), port **`5432`** (internal).  
`POSTGRES_HOST_PORT` is only the **host** port mapped on the VPS (default **5434**).

### Default host ports

Change in `api.env` / `web.env` if another project already uses these ports:

```env
POSTGRES_HOST_PORT=5434
API_HOST_PORT=8080
WEB_HOST_PORT=3000
```

Then run `.\sync-server-env.ps1` and re-copy `server-files/` to the VPS.

### Publish settings (domain, nginx, CORS, ports)

One script updates `api.env`, `web.env`, and your shared `nginx.conf`:

```powershell
cd challingo-deploy
.\Set-PublishSettings.ps1 `
    -Domain yourdomain.ir `
    -ApiPort 8083 `
    -WebPort 3003 `
    -PostgresPort 5434 `
    -TlsMode Http `
    -NginxPriority First `
    -NginxConfigPath C:\path\to\nginx.conf
```

```bash
# macOS / Linux (requires pwsh)
./set-publish-settings.sh -Interactive
# or same named params as the .ps1
./set-publish-settings.sh -Domain yourdomain.ir -ApiPort 8083 -WebPort 3003 -TlsMode Http
```

| Parameter | Purpose |
|-----------|---------|
| `-Domain` | Public host (web `/`, API `/api/`) |
| `-ApiPort` / `-WebPort` / `-PostgresPort` | Docker host ports (`API_HOST_PORT`, `WEB_HOST_PORT`, `POSTGRES_HOST_PORT`) |
| `-TlsMode Http` | HTTP only (+ optional HTTPS→HTTP redirect stub) |
| `-TlsMode Https` | HTTP→HTTPS redirect + Let's Encrypt on 443 |
| `-NginxPriority First` | Insert before other apps (recommended for Http-only) |
| `-UploadMaxBodySize` | `client_max_body_size` for uploads (e.g. `520M`) |
| `-Registry` | Push registry on dev (`api.env` / `web.env`); server gets `127.0.0.1:port` for VPS pull |
| `-Tag` | Image tag for api/web/worker (`TAG` in api.env and web.env) |

Also sets `NEXT_PUBLIC_API_URL`, `Cors__AllowedOrigins__*`, then runs `sync-server-env.ps1`.

Run **`.\Set-PublishSettings.ps1`** with no arguments for an interactive wizard (prompts for domain, ports, registry, tag, nginx path, etc.).

See `publish-settings.example.ps1` and `nginx/nginx.multi-app.example.conf`.

**Post-run:** rebuild web (`build-and-push-web.ps1`), deploy nginx to VPS (`nginx -t`), then API push + `server-up.sh`.

**Postgres:** one container per project (recommended). Use a different `POSTGRES_HOST_PORT` per project.

**Registry:** one shared registry on `:8585` is fine — images are separated by name (`challingo-api` vs `other-api`).

### Worker (background service)

The worker **always runs** with api and web. A fresh scaffold has no custom jobs yet — it only checks Postgres, then logs an **idle heartbeat** every `Worker__PollIntervalSeconds` (default 300s).

**Docker:** Worker Dockerfile final stage must use `mcr.microsoft.com/dotnet/aspnet:10.0` (same as API), not `runtime:10.0`, because Worker references Core/Infrastructure with `Microsoft.AspNetCore.*` packages.

1. `.\build-and-push-worker.ps1` — push `challingo-worker:TAG` (same `TAG` as api/web in `api.env`)
2. `.\sync-server-env.ps1`
3. `./server-up.sh` on VPS

Add your own `BackgroundService` classes in `challingo-api/Challingo.Worker/Jobs/` and register them in `Program.cs`. Keep `WorkerIdleJob` until you have a long-running job, or remove it when custom jobs take over.

Local dev: set `Worker__EnableSampleJob=true` in `challingo-api/.env` for extra demo logs.

If the worker **restarts in a loop**, check `docker logs challingo-worker` — usually missing `ConnectionStrings__Database` (run sync) or worker image not in registry (run build-and-push-worker).

---

## Docker networking (project grouping)

Naming convention: **`challingo-network`**, **`challingo-postgres-data`**, compose project **`name: challingo`**.

| Concept | Challingo value | What it does |
|---------|--------------------------|--------------|
| **Compose project** | `name: challingo` | Groups containers in `docker compose ps` |
| **Custom network** | `challingo-network` | Private LAN for postgres ↔ api ↔ web ↔ worker; DNS by service name |
| **Postgres image** | `challingo-postgres:16-alpine` | Tagged from official `postgres:16-alpine` on first deploy |
| **Named volumes** | `challingo-postgres-data` | Data isolated from other projects |

```
                    challingo-network (bridge)
                    ┌─────────────────────────────┐
  host :5434 ──────►│ postgres                    │
  host :8080 ──────►│ challingo-api       │
  host :3000 ──────►│ challingo-web       │
                    │ Challingo.Worker    │  (no host port)
                    └─────────────────────────────┘

  registry :8585    (optional / often shared — not on challingo-network)
```

- **API → Postgres:** `Host=postgres` on `challingo-network`, not `127.0.0.1`.
- **Postgres/API/Web** bind to `127.0.0.1` on the host (nginx/reverse-proxy friendly).
- **Another project** on the same VPS gets its own network (e.g. `otherproject-network`).

```bash
docker network ls | grep challingo
docker network inspect challingo-network
docker compose ps
```

Remove old unused networks after migrating (only if empty):

```bash
docker network rm old-project_app-net old-project_default
```

---

## First-time setup

### 1. Dev — configure

Edit `challingo-deploy/api.env` — `REGISTRY`, ports, JWT, connection string, **`Worker__*`** toggles.

Edit `challingo-deploy/web.env` — `REGISTRY`, `WEB_HOST_PORT`, `NEXT_PUBLIC_*`.

Edit `challingo-deploy/server-files/.env` **once** for VPS-only values (preserved by sync):

```env
REGISTRY=127.0.0.1:8585
REGISTRY_HOST_PORT=8585
```

### 2. Dev — sync, build, push

```powershell
cd challingo-deploy
.\sync-server-env.ps1
.\build-and-push-api.ps1
.\build-and-push-web.ps1
.\build-and-push-worker.ps1
.\build-and-push-all.ps1
```

`sync-server-env.ps1` sets `API_VERSION` / `WEB_VERSION` / `WORKER_VERSION` from `api.env` / `web.env` `TAG` values and writes ports/settings to `server-files/.env`.

### 3. Copy to VPS

Copy the whole **`server-files/`** folder to the server.

### 4. VPS — deploy

```bash
cd /path/to/server-files
chmod +x server-up.sh server-down.sh load-env.sh
sed -i 's/\r$//' .env load-env.sh server-up.sh server-down.sh   # if copied from Windows
./server-up.sh
```

---

## Every release

### Dev

1. Bump `TAG` in `api.env` and/or `web.env`
2. `.\sync-server-env.ps1`
3. `.\build-and-push-all.ps1` (or run api / web / worker scripts separately)
4. Copy updated **`server-files/`** to VPS

### VPS

```bash
cd /path/to/server-files
./server-up.sh
```

To stop the stack (containers + `challingo-network`, keeps volumes):

```bash
./server-down.sh
```

---

## What `./server-up.sh` does

**`server-up.sh` runs `docker compose` for you.** No separate compose command needed.

| Step | Command | Purpose |
|------|---------|---------|
| 1 | `docker compose up -d postgres` | Start Postgres (removes orphaned containers if needed) |
| 2 | Ensure registry | Reuse existing at `REGISTRY`, or create project registry |
| 3 | `docker pull/tag/push` | Promote versioned tag → `:latest` |
| 4 | `docker compose pull` api + web + worker | Pull latest images |
| 5 | `docker compose up -d` api + web + worker | Start or restart app containers |
| 6 | `docker compose ps` | Show status |

Do **not** run plain `docker compose up -d` alone before promote — `:latest` will not exist yet.

---

## What `./server-down.sh` does

**`server-down.sh` stops the compose project for you.** Use it when you want to take the stack offline without deleting data.

| Step | Command | Purpose |
|------|---------|---------|
| 1 | `docker compose --profile registry down --remove-orphans` | Stop postgres, api, web, worker, and project registry |
| 2 | Remove network | Drops **`challingo-network`** when no containers remain |

Named volumes (`challingo-postgres-data`, uploads, registry) are **kept** unless you pass `--volumes`.

```bash
cd /path/to/server-files
chmod +x server-down.sh
./server-down.sh
```

To also delete postgres data, uploads, and registry storage:

```bash
./server-down.sh --volumes
```

Start again with `./server-up.sh`.

---

## Troubleshooting

### `$'\r': command not found`

```bash
sed -i 's/\r$//' .env load-env.sh server-up.sh server-down.sh
```

### Container name already in use

```bash
docker rm -f challingo-postgres challingo-api challingo-web challingo-worker
./server-up.sh
```

`server-up.sh` also removes orphaned containers automatically. Data stays in volume `challingo-postgres-data`.

### Port already allocated

Edit ports in `api.env` / `web.env`, run `.\sync-server-env.ps1`, re-copy `server-files/`.

### Push fails: HTTP response to HTTPS client

Add VPS registry to Docker Desktop `insecure-registries` (see Prerequisites).

### Replace build without bumping TAG

Dev: rebuild and push same `TAG`. VPS: `docker rmi ...:TAG ...:latest -f` then `./server-up.sh`.

### Health check (VPS)

```bash
cd server-files
chmod +x health-check.sh
./health-check.sh
```

### CI example

See `ci/github-actions.example.yml` in the deploy folder (copied to `challingo-deploy/ci/`). Copy to repo `.github/workflows/` and adjust paths.

---

## File tree

Monorepo layout (example for project `my-shop`):

```text
my-shop/
├── my-shop-api/          # ASP.NET Core
├── my-shop-api/MyShop.Worker/  # background worker host (optional at scaffold with -SkipWorker)
├── my-shop-web/          # Next.js
├── my-shop-app/          # Flutter
└── my-shop-deploy/       # copy server-files* to VPS
    ├── api.env             # includes Worker__* keys
    ├── web.env
    ├── sync-server-env.ps1
    ├── sync-server-env-staging.ps1
    ├── promote-staging-to-prod.sh
    ├── build-and-push-api.ps1
    ├── build-and-push-web.ps1
    ├── build-and-push-worker.ps1
    ├── build-and-push-all.ps1
    ├── build-and-push-all.sh
    ├── ci/
    │   └── github-actions.example.yml
    ├── server-files/
    │   ├── .env
    │   ├── docker-compose.yml
    │   ├── server-up.sh
    │   ├── server-down.sh
    │   └── health-check.sh
    └── server-files-staging/
        ├── .env
        ├── docker-compose.yml
        ├── server-up-staging.sh
        └── server-down-staging.sh
```

## Staging (path twin on the same domain)

After build/push, deploy staging first, then promote the same `TAG` to production — no rebuild.

| | Production | Staging |
|--|------------|---------|
| Web | `/{domain}/` | `/staging.{domain}/` |
| API | `/{domain}/api/` | `/staging.{domain}/api/` |
| Images | `:latest` | `:staging` (promoted from `TAG`) |
| Data | `server-files/` volumes | `server-files-staging/` volumes |

```bash
# VPS
cd server-files-staging && ./server-up-staging.sh
# QA → promote:
cd .. && ./promote-staging-to-prod.sh
```

`Set-PublishSettings` writes nginx server blocks for production and staging hostnames (staging ports = prod + 1). Web uses relative `/api` so one image works on both hosts.