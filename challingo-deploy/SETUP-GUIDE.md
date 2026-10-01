# Challingo — setup and configuration guide

> **Quick daily commands:** [QUICK-START.md](./QUICK-START.md) · [QUICK-START.fa.md](./QUICK-START.fa.md)  
> **Deploy script reference:** [README.md](./README.md)

This is the **single source of truth** for initializing and configuring **Challingo**.  
Follow the phases in order the first time; later, jump to the section you need.

**Example project name used below:** `MyShop` → folders `my-shop-api`, `my-shop-deploy`, Docker prefix `myshop`.

---

## 1. How configuration works

```text
DEV MACHINE (you edit these)
────────────────────────────
  my-shop-deploy/api.env      ← master runtime settings (API + Worker__*, same TAG as web)
  my-shop-deploy/web.env      ← web build + NEXT_PUBLIC_* (baked into image)

        │
        │  .\sync-server-env.ps1   (or .sh on Linux)
        ▼

  my-shop-deploy/server-files/.env   ← generated; copy folder to VPS

VPS (you run these)
───────────────────
  ./server-up.sh        ← starts postgres, optional rabbit/observability, api, web, worker
  ./health-check.sh
  ./backup-db.sh
```

| Rule | Detail |
|------|--------|
| **Single source** | Put almost everything in **`api.env`**. `sync-server-env` merges `api.env` + `web.env` into `server-files/.env`. |
| **Do not hand-edit** | Avoid editing `server-files/.env` on the dev PC — re-run sync after changing `api.env` / `web.env`. |
| **ASP.NET env keys** | Use `Section__SubKey=value` (double underscore) for nested appsettings. |
| **Web public vars** | `NEXT_PUBLIC_*` only in **`web.env`** — they are embedded at **`npm run build`** / Docker web build. Changing them requires **rebuild web image**. |
| **Local API `.env`** | `challingo-api/.env` is for **local dotnet run** only (Postgres on `127.0.0.1:5434`). Deploy settings stay in **`api.env`**. |

---

## 2. What you get after scaffolding

| Folder | Purpose |
|--------|---------|
| `challingo-api` | ASP.NET API, EF migrations, `.env` for local dev |
| `challingo-web` | Next.js app |
| `challingo-api/Challingo.Worker` | .NET worker (OTP email/SMS delivery, sample jobs) |
| `challingo-deploy` | **This guide**, `api.env`, `web.env`, `server-files/` |
| `challingo-app` | Flutter app (optional) |

---

## 3. Prerequisites (one-time per machine)

| Tool | Used for |
|------|----------|
| .NET SDK 10+ | API, worker |
| Node.js 20+ | Web |
| Docker Desktop | Local Postgres, image build/push |
| PowerShell 5.1+ (Windows) or **PowerShell 7+ / `pwsh`** (macOS/Linux) | Scaffold + deploy scripts |
| `cursor-scaffold` repo | `New-Project` (`.ps1` or `.sh`); optional `Install-ApiTemplate` verify |

**macOS / Linux:** `brew install --cask powershell`, then `chmod +x *.sh scripts/*.sh scripts/lib/*.sh gui/start-gui.sh`. See `cursor-scaffold/docs/en/MACOS.md`.

**Optional:** Flutter + Mason (mobile app), `gh` CLI (CI).

---

## 4. Phase A — Create the project

From the **cursor-scaffold** folder (path on your machine):

```powershell
# Windows
cd path\to\cursor-scaffold
.\New-Project.ps1 -ProjectName MyShop
```

```bash
# macOS / Linux
cd path/to/cursor-scaffold
./new-project.sh -ProjectName MyShop
```

Result (projects are created next to cursor-scaffold by default, or under `DefaultOutputRoot` in `scaffold-config.local.psd1`):

```text
path/to/my-shop/
  my-shop-api/
  my-shop-web/
  my-shop-api/MyShop.Worker/
  my-shop-deploy/      ← start configuration here
  my-shop-app/
```

Git: scaffold does **not** `git init` the monorepo root by default. Initialize git inside `my-shop-api`, `my-shop-web`, etc., or use `-InitGit` on `New-Project` for one root repo.

---

## 5. Phase B — Shared dev Postgres (local PC only)

One Postgres container for **all** scaffold projects on your machine.

```powershell
cd path\to\cursor-scaffold\dev-postgres
docker compose up -d
.\create-db.ps1 myshop
```

```bash
# macOS / Linux
cd path/to/cursor-scaffold/dev-postgres
docker compose up -d
./create-db.sh myshop
```

| Setting | Value |
|---------|-------|
| Host | `127.0.0.1` |
| Port | `5434` |
| User | `scaffoldadmin` |
| Password | `changeme` |
| Database | `myshop` (same as `challingo` for this project) |

The scaffold already created `my-shop-api/.env` with this connection string.

Apply migrations locally:

```powershell
cd path\to\my-shop\my-shop-api
dotnet ef database update --project MyShop.Infrastructure --startup-project MyShop.Api
```

---

## 6. Phase C — Run locally (smoke test)

### 6.1 API

```powershell
cd my-shop-api
dotnet run --project MyShop.Api
```

Check:

- Swagger: `http://127.0.0.1:5128/swagger` or the port in `launchSettings.json`
- Health: `http://127.0.0.1:5128/health/live` and `/health/ready`
- OTP dev: request phone/email OTP — code appears in **console** (`Otp__DevMode=true`)

### 6.2 Worker (optional locally)

Copy worker env or use defaults in `my-shop-api/.env`:

```powershell
cd my-shop-api
dotnet run --project MyShop.Worker
```

With defaults, worker logs **idle** (email/SMS delivery off until configured).

### 6.3 Web

```powershell
cd my-shop-web
# .env.local defaults to http://localhost:5128 (Kestrel)
npm install
npm run dev
```

Open `http://127.0.0.1:3000`.

### 6.4 Generate API TypeScript types (optional)

With API running:

```powershell
cd my-shop-web
npm run generate-api-client
```

Creates `src/lib/api-schema.ts` from OpenAPI.

---

## 7. Phase D — Configure deploy env (single source of truth)

All paths below: **`my-shop-deploy/`** (your `challingo-deploy/`).

### 7.1 Edit `api.env` (master file)

Open `api.env`. This file controls API runtime, Postgres, JWT, auth, RabbitMQ, email, logging, health, backups, and most VPS behavior.

Passwords that contain `#`, spaces, or quotes **must** be written once and left alone (GUI/sync now unquote before re-saving). If a value looks like `"\"\\\"…\\\""`, repair with:

```bash
python3 /path/to/cursor-scaffold/scripts/repair-env-escapes.py api.env server-files/.env server-files-staging/.env
```

Or from PowerShell (after `. .\load-env.ps1`): `Repair-EnvFileEscapes -Path .\api.env`

**Minimal example — local push to registry on your PC:**

```env
TAG=1.0.0
REGISTRY=host.docker.internal:5000

API_HOST_PORT=8080
POSTGRES_HOST_PORT=5434
POSTGRES_USER=scaffoldadmin
POSTGRES_PASSWORD=changeme
POSTGRES_DB=myshop

ConnectionStrings__Database=Host=postgres;Port=5432;Database=myshop;Username=scaffoldadmin;Password=changeme;Pooling=true

Jwt__Key=change-me-use-at-least-32-characters-long-secret
Jwt__Issuer=MyShop
Jwt__Audience=MyShop-Users
Jwt__ExpirationInMinutes=30
Jwt__RefreshTokenExpirationDays=7

Cors__AllowedOrigins__0=http://127.0.0.1:3000
Cors__AllowedOrigins__1=http://localhost:3000
```

**Platform toggles (safe dev defaults — already in template):**

```env
Serilog__Enabled=true
Serilog__MinimumLevel=Information
Serilog__WriteToFile=false
Health__Enabled=true
Database__AutoMigrate=false

Maintenance__Enabled=false
Auth__OtpRateLimitPerMinute=10
Otp__MaxVerifyAttempts=5

# Traffic resilience (API + Worker SMS HttpClient)
RateLimit__Enabled=true
RateLimit__GlobalPerMinute=120
RequestTimeout__Enabled=true
RequestTimeout__Seconds=30
Http__Enabled=true
Http__TimeoutSeconds=15
Http__RetryCount=2
Http__RetryBaseDelayMs=200
Http__CircuitBreakFailures=5
Http__CircuitBreakSeconds=30
Idempotency__Enabled=false
Idempotency__TtlHours=24
Idempotency__HeaderName=Idempotency-Key

Storage__Provider=Local
Storage__LocalRoot=wwwroot/uploads

BACKUP_DIR=./backups
BACKUP_RETENTION_DAYS=14

Observability__Enabled=false
RabbitMq__Enabled=false
```

**Auth (email + phone OTP):**

```env
Auth__EnablePasswordLogin=true
Auth__EnableEmailAuth=true
Auth__EnablePhoneAuth=true

Otp__DevMode=true
Otp__LogOnly=true
```

**When you enable production messaging later:**

```env
RabbitMq__Enabled=true
RabbitMq__HostName=rabbitmq
RabbitMq__Port=5672
RabbitMq__UserName=scaffold
RabbitMq__Password=changeme
RabbitMq__EmailQueueName=myshop.email.outbound
RabbitMq__SmsOtpQueueName=myshop.otp.sms
RabbitMq__EmailDeadLetterQueueName=myshop.email.deadletter
RabbitMq__SmsOtpDeadLetterQueueName=myshop.otp.sms.deadletter

Otp__DevMode=false
Otp__LogOnly=false

Email__Enabled=true
Email__FromAddress=you@gmail.com
Email__SmtpUsername=you@gmail.com
Email__SmtpPassword=your-app-password
Email__SmtpHost=smtp.gmail.com
Email__SmtpPort=587

Sms__Provider=SmsIr
Sms__SmsIrApiKey=your-sms-ir-key
Sms__SmsIrVerifyTemplateId=100000
Sms__SmsIrVerifyCodeParameterName=CODE
```

### 7.2 Edit `web.env`

```env
TAG=1.0.0
REGISTRY=host.docker.internal:5000
WEB_HOST_PORT=3000

NEXT_PUBLIC_MAINTENANCE_MODE=false
NEXT_PUBLIC_API_URL=http://127.0.0.1:8080
NEXT_PUBLIC_WS_URL=http://127.0.0.1:8080
```

For production domain (example):

```env
NEXT_PUBLIC_API_URL=https://shop.example.com/api
NEXT_PUBLIC_WS_URL=https://shop.example.com/api
NEXT_PUBLIC_GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

Set the **same Web OAuth client ID** in `api.env` as `Google__ClientId` (comma-separated if you add Android/iOS client IDs).

Or use **`Set-PublishSettings.ps1`** (sets ports, CORS, `NEXT_PUBLIC_*`, nginx block).

### 7.3 Google Sign-In checklist

| Layer | Config |
|-------|--------|
| **Google Cloud** | Web OAuth client; **Authorized JavaScript origins** include `http://localhost:3000` and your production domain |
| **`web.env`** | `NEXT_PUBLIC_GOOGLE_CLIENT_ID` = Web client ID → **rebuild web image** |
| **`api.env`** | `Google__ClientId` = same Web ID (+ optional Android/iOS IDs, comma-separated) → **sync + recreate API** |
| **Verify on VPS** | `docker exec challingo-api printenv Google__ClientId` |
| **Verify network** | `docker exec challingo-api wget -qO- https://www.googleapis.com/oauth2/v3/certs` |

On VPS in restricted regions, outbound HTTPS to Google may be blocked — the API returns a clear error; that is infrastructure, not an app bug.

Local dev: set `NEXT_PUBLIC_GOOGLE_CLIENT_ID` in `challingo-web/.env.local` and `Google__ClientId` in `challingo-api/.env` (same Web client ID).

### 7.4 Worker settings in `api.env`

```env
TAG=1.0.0
REGISTRY=host.docker.internal:5000

Worker__PollIntervalSeconds=300
Worker__EnableSampleJob=false
Worker__EnableEmailDelivery=false
Worker__EnableSmsOtpDelivery=false
```

Enable delivery only when Rabbit + SMTP/sms.ir are configured in **`api.env`**:

```env
Worker__EnableEmailDelivery=true
Worker__EnableSmsOtpDelivery=true
```

### 7.5 Traffic resilience (`api.env`)

Built into the API (and Worker SMS `HttpClient`). All keys sync via `sync-server-env` (`.ps1` / `.sh`).

| Concern | Keys | Behavior |
|---------|------|----------|
| Global rate limit | `RateLimit__Enabled`, `RateLimit__GlobalPerMinute` | Fixed window per IP, or per authenticated user id after JWT. `/health*` and `/swagger*` exempt. Returns **429**. |
| Auth / OTP limit | `Auth__OtpRateLimitPerMinute` | Policy `auth-otp` on all `AuthController` routes (Google, login, refresh, OTP, …). |
| Request timeout | `RequestTimeout__Enabled`, `RequestTimeout__Seconds` | ASP.NET default policy (clamp 5–300s). Health endpoints disable timeout. |
| Outbound HTTP | `Http__Enabled`, `Http__TimeoutSeconds`, `Http__RetryCount`, `Http__RetryBaseDelayMs`, `Http__CircuitBreakFailures`, `Http__CircuitBreakSeconds` | Microsoft.Extensions.Http.Resilience on Worker SMS (sms.ir): attempt timeout, exponential retry + jitter, circuit breaker. |
| Idempotency | `Idempotency__Enabled`, `Idempotency__TtlHours`, `Idempotency__HeaderName` | **Off by default.** When on, mutating requests with `Idempotency-Key` replay the first 2xx body from memory cache. |

Startup log line includes `RateLimit=…`, `RequestTimeout=…`, `HttpResilience=…`, `Idempotency=…`.

Tune for production load (raise `RateLimit__GlobalPerMinute`, keep timeouts sane). Enable idempotency for payments/webhooks when clients retry POSTs.

### 7.5.1 Redis, realtime (SignalR) and scheduler (`api.env`)

| Concern | Keys | Behavior |
|---------|------|----------|
| Redis | `Redis__Enabled`, `Redis__ConnectionString`, `Redis__InstanceName`, `REDIS_PASSWORD`, `REDIS_HOST_PORT` | **Off by default.** When on: `server-up.sh` starts the `redis` compose profile (AOF, `noeviction`); API + Worker share leaderboards (`ILeaderboardStore`, sorted sets), `IDistributedCache`, and the SignalR backplane. `sync-server-env` rebuilds `Redis__ConnectionString` from `REDIS_PASSWORD`. `/health/ready` pings Redis. Off = in-memory fallbacks (one process only). |
| Realtime | `Realtime__Enabled`, `Realtime__HubPath`, `Realtime__KeepAliveSeconds`, `Realtime__ClientTimeoutSeconds`, `Realtime__EnableDetailedErrors` | SignalR hub at `/hubs/app` (JWT via `?access_token=`). Connections auto-join `user:{id}`; clients `Subscribe("topic")` for groups like `challenge:{id}`. Server code pushes with `IRealtimeNotifier`. The Worker can push **only when Redis is on** (backplane). nginx blocks already forward WebSocket upgrades. |
| Scheduler | `Scheduler__Enabled`, `Scheduler__Jobs__<Name>__Enabled`, `Scheduler__Jobs__<Name>__Cron` | Quartz in the Worker, cron in **UTC** (seconds field first: `0 0 * * * ?` = hourly). In-memory job store → run **one** Worker replica and make jobs idempotent (missed runs fire once on recovery). Register jobs in `Worker/Program.cs` with `AddScaffoldJob<TJob>`. |

Enable for a realtime/leaderboard app:

```env
Redis__Enabled=true
REDIS_PASSWORD=<strong-random>
```

### 7.5.2 Rewarded ads and Plus (`api.env` + app build)

Challingo grants ad rewards and Plus **only from the server**: AdMob's signed callback and RevenueCat's subscriber record.

**AdMob (rewarded ads: +1 run and +5 stars, max 3 a day)**
1. Create the app and a **Rewarded** ad unit for iOS and for Android in AdMob.
2. On each rewarded ad unit, turn on **Server-side verification** with the URL `https://<api-host>/api/webhooks/admob/ssv`.
3. Optional: `Monetization__AdMob__AllowedAdUnits=<ios unit id>,<android unit id>` (other units are ignored).
4. App build: `--dart-define=ADMOB_REWARDED_IOS=… --dart-define=ADMOB_REWARDED_ANDROID=…`, the iOS app id in `ios/Flutter/{Debug,Release}.xcconfig` (`ADMOB_APP_ID`), the Android app id with `-PadmobAppId=…` (or edit `android/app/build.gradle.kts`).
5. Google's test units (the defaults) never call the verification URL; with `Monetization__AllowDevRewards=true` (development only) the app asks the API for a test reward instead.
6. Ads need a consent choice first (Google UMP); configure the GDPR / US-states messages in AdMob → Privacy & messaging.

**RevenueCat (Plus: unlimited ranked runs)**
1. Create the products (e.g. monthly, yearly) in App Store Connect and Google Play, add them in RevenueCat, attach them to the entitlement **`plus`** and to the current offering.
2. RevenueCat → Integrations → Webhooks: URL `https://<api-host>/api/webhooks/revenuecat`, Authorization header value = `Monetization__RevenueCat__WebhookAuthorization`.
3. `Monetization__RevenueCat__SecretApiKey=sk_…` (secret key; the API re-reads subscribers with it).
4. App build: `--dart-define=RC_APPLE_KEY=appl_… --dart-define=RC_GOOGLE_KEY=goog_…` (public SDK keys). The app user id is the player id.
5. `Monetization__AllowDevRewards` must be **false** in production (it enables test ads and test Plus).

### 7.6 Sync to `server-files/.env`

```powershell
cd my-shop-deploy
.\sync-server-env.ps1
```

```bash
./sync-server-env.sh
```

You should see: `Updated .../server-files/.env`

**Never skip this** before copying `server-files/` to the VPS.

---

## 8. Phase E — Recipe: production profile on VPS

Do this **on the dev machine** in `api.env` / `web.env`, then sync, build, deploy.

### Step E.1 — Domain and ports

```powershell
cd my-shop-deploy
.\Set-PublishSettings.ps1 `
  -Domain shop.example.com `
  -ApiPort 8085 `
  -WebPort 3005 `
  -PostgresPort 5434 `
  -TlsMode Https `
  -Registry YOUR_VPS_IP:8585 `
  -Tag 1.0.1 `
  -NginxConfigPath C:\path\to\nginx.conf
```

This updates `api.env`, `web.env`, CORS, nginx snippet (including separate staging hostname), and (when `-Registry` / `-Tag` are set) image push settings. It runs `sync-server-env.ps1` and `sync-server-env-staging.ps1` if present.

### Step E.2 — Production flags in `api.env`

```env
Database__AutoMigrate=true
Otp__DevMode=false
Otp__LogOnly=false
RabbitMq__Enabled=true
Email__Enabled=true
# ... SMTP + sms.ir keys ...
```

### Step E.3 — Worker delivery toggles in `api.env`

```env
Worker__EnableEmailDelivery=true
Worker__EnableSmsOtpDelivery=true
```

### Step E.4 — Sync again

```powershell
.\sync-server-env.ps1
```

### Step E.5 — Build and push images

```powershell
.\build-and-push-api.ps1
.\build-and-push-web.ps1
.\build-and-push-worker.ps1
```

Each script reads `TAG` and `REGISTRY` from its env file.

**Registry push vs VPS pull**

| Machine | `REGISTRY` in env | Purpose |
|---------|-------------------|---------|
| Dev `api.env` / `web.env` | `YOUR_VPS_IP:8585` | `build-and-push-*.ps1` push over the network |
| VPS `server-files/.env` | `127.0.0.1:8585` | `server-up.sh` pull on localhost (set by `sync-server-env.ps1`) |

Host port **8585** maps to registry container port **5000**. Image lines in `server-files/.env` are full paths (e.g. `127.0.0.1:8585/my-shop-api:latest`), not `${REGISTRY}/...`.

**VPS Docker (one-time)** — add to `/etc/docker/daemon.json`:

```json
{
  "insecure-registries": ["127.0.0.1:8585"]
}
```

Then `sudo systemctl restart docker`.

### Step E.6 — Copy to VPS and start

Copy **`server-files/`** and **`server-files-staging/`** to the server (scp, rsync, etc.).

On the VPS — **staging first** (QA at `https://staging.{domain}/` (or `http://IP:81/`)):

```bash
cd server-files-staging
chmod +x server-up-staging.sh server-down-staging.sh health-check.sh backup-db.sh restore-db.sh load-env.sh
sed -i 's/\r$//' .env *.sh
./server-up-staging.sh
```

After QA, promote the same TAG to production:

```bash
cd /path/to/deploy   # folder that contains both server-files*
chmod +x promote-staging-to-prod.sh
./promote-staging-to-prod.sh
```

Or start production directly:

```bash
cd server-files
chmod +x server-up.sh server-down.sh health-check.sh backup-db.sh restore-db.sh load-env.sh
sed -i 's/\r$//' .env *.sh
./server-up.sh
./health-check.sh
```

Nginx (from `Set-PublishSettings`) routes `staging.{domain}` to staging host ports (prod ports + 1).

### Step E.7 — Backups (cron example)

```bash
cd /path/to/server-files
./backup-db.sh
# Optional cron: 0 3 * * * cd /path/to/server-files && ./backup-db.sh
```

Set in `api.env` before sync:

```env
BACKUP_DIR=./backups
BACKUP_RETENTION_DAYS=14
BACKUP_OFFSITE_PATH=/var/backups/myshop
```

---

## 9. Phase F — Maintenance mode

**API only** (instant after redeploy/sync):

```env
Maintenance__Enabled=true
Maintenance__Message=We will be back soon.
# Maintenance__BypassKey=secret-for-admins
```

Sync and restart API container (or full `server-up.sh`).

**Web** (requires rebuild):

```env
# web.env
NEXT_PUBLIC_MAINTENANCE_MODE=true
```

Then `.\build-and-push-web.ps1` and redeploy.

---

## 10. Phase G — Observability (optional)

In `api.env`:

```env
Observability__Enabled=true
SEQ_HOST_PORT=5341
UPTIME_KUMA_HOST_PORT=3001
```

`server-up.sh` enables compose profile `observability` (Seq + Uptime Kuma).

- Seq UI: `http://127.0.0.1:5341` on VPS
- Point Uptime Kuma at `http://127.0.0.1:API_PORT/health/ready`

---

## 11. Updating a release (bump version)

1. Set same new `TAG=1.0.2` in `api.env`, `web.env`
2. `.\sync-server-env.ps1`
3. `.\build-and-push-api.ps1` (and web/worker if changed)
4. Copy `server-files/` to VPS (at least `.env` if only env changed)
5. `./server-up.sh` on VPS

---

## 12. Auth API quick reference

Base path: `/api/auth`

| Method | Path | When enabled |
|--------|------|----------------|
| POST | `login` | `Auth__EnablePasswordLogin` |
| POST | `register/email` | `Auth__EnableEmailAuth` |
| POST | `register/email/confirm` | email OTP signup |
| POST | `otp/request` | email login OTP |
| POST | `otp/verify` | email login confirm |
| POST | `check-phone` | `Auth__EnablePhoneAuth` |
| POST | `register` | phone signup OTP |
| POST | `register/confirm` | phone signup confirm |
| POST | `login/otp/request` | phone login OTP |
| POST | `login/otp/confirm` | phone login confirm |
| POST | `refresh` | always (with valid refresh token) |
| POST | `logout` | always |

**Dev OTP:** with `Otp__DevMode=true`, codes print in API logs.  
**Prod OTP:** `RabbitMq__Enabled=true`, worker delivery on, `Otp__LogOnly=false`.

---

## 13. Appendix — env variable reference

### 13.1 `api.env` — build & VPS host

| Variable | Example | Purpose |
|----------|---------|---------|
| `TAG` | `1.0.0` | Image version tag for push |
| `REGISTRY` | `203.0.113.10:8585` | Docker registry host:port |
| `API_HOST_PORT` | `8080` | VPS localhost port for API |
| `POSTGRES_HOST_PORT` | `5434` | VPS localhost port for Postgres |
| `POSTGRES_USER` | `scaffoldadmin` | Postgres user |
| `POSTGRES_PASSWORD` | `changeme` | Postgres password |
| `POSTGRES_DB` | `myshop` | Postgres database name |

### 13.2 `api.env` — ASP.NET (`Section__Key`)

| Variable | Default | Purpose |
|----------|---------|---------|
| `ConnectionStrings__Database` | see template | DB connection (use `Host=postgres` on VPS) |
| `Jwt__Key` | (change me) | Signing key, min 32 chars |
| `Jwt__Issuer` | `Challingo` | JWT issuer |
| `Jwt__Audience` | `Challingo-Users` | JWT audience |
| `Jwt__ExpirationInMinutes` | `30` | Access token lifetime |
| `Jwt__RefreshTokenExpirationDays` | `7` | Refresh token lifetime |
| `Cors__AllowedOrigins__0` | `http://127.0.0.1:3000` | CORS origin 1 |
| `Serilog__Enabled` | `true` | Structured logging |
| `Serilog__MinimumLevel` | `Information` | Log level |
| `Serilog__WriteToFile` | `false` | File sink on VPS |
| `Health__Enabled` | `true` | `/health/live` and `/health/ready` |
| `Database__AutoMigrate` | `false` | Run EF migrate on API start |
| `Maintenance__Enabled` | `false` | API 503 maintenance mode |
| `Maintenance__BypassKey` | (empty) | Header `X-Maintenance-Bypass` |
| `Storage__Provider` | `Local` | File storage backend |
| `Storage__LocalRoot` | `wwwroot/uploads` | Upload directory |
| `Auth__EnablePasswordLogin` | `true` | Password login |
| `Auth__EnableEmailAuth` | `true` | Email OTP auth |
| `Auth__EnablePhoneAuth` | `true` | Phone OTP auth |
| `Auth__OtpRateLimitPerMinute` | `10` | Rate limit per IP on auth/OTP routes (`auth-otp` policy) |
| `RateLimit__Enabled` | `true` | Global API fixed-window limiter (IP or user id) |
| `RateLimit__GlobalPerMinute` | `120` | Global permits per minute (`/health` + `/swagger` exempt) |
| `RequestTimeout__Enabled` | `true` | ASP.NET default request timeout |
| `RequestTimeout__Seconds` | `30` | Timeout seconds (5–300; health endpoints exempt) |
| `Http__Enabled` | `true` | Outbound HttpClient resilience (timeout/retry/circuit) |
| `Http__TimeoutSeconds` | `15` | Per-attempt outbound timeout |
| `Http__RetryCount` | `2` | Transient retries with exponential backoff + jitter |
| `Http__RetryBaseDelayMs` | `200` | Base retry delay |
| `Http__CircuitBreakFailures` | `5` | Circuit breaker minimum throughput |
| `Http__CircuitBreakSeconds` | `30` | Circuit open duration |
| `Idempotency__Enabled` | `false` | Optional `Idempotency-Key` replay for mutating requests |
| `Idempotency__TtlHours` | `24` | How long to remember a key |
| `Idempotency__HeaderName` | `Idempotency-Key` | Client header name |
| `Otp__DevMode` | `true` | Log OTP codes |
| `Otp__LogOnly` | `true` | Do not queue SMS/email |
| `Otp__MaxVerifyAttempts` | `5` | Max wrong OTP attempts |
| `Sms__Provider` | `LogOnly` | `LogOnly` or `SmsIr` |
| `Sms__SmsIrApiKey` | | sms.ir API key |
| `Sms__SmsIrVerifyTemplateId` | | sms.ir template id |
| `RabbitMq__Enabled` | `false` | Enable Rabbit + messaging profile |
| `RabbitMq__HostName` | `rabbitmq` | Docker service name on VPS |
| `Email__Enabled` | `false` | Allow email OTP queue |
| `Email__SmtpHost` | `smtp.gmail.com` | SMTP server |
| `Google__ClientId` | | Web OAuth client ID(s) for Google Sign-In (comma-separated) |
| `Worker__EnableEmailDelivery` | `false` | Worker consumes email queue |
| `Worker__EnableSmsOtpDelivery` | `false` | Worker consumes SMS queue |
| `Observability__Enabled` | `false` | Seq + Uptime Kuma profile |
| `BACKUP_DIR` | `./backups` | DB backup output dir on VPS |
| `BACKUP_RETENTION_DAYS` | `14` | Delete older backups |
| `BACKUP_OFFSITE_PATH` | | Optional copy target |

Worker-specific `Worker__PollIntervalSeconds` and `Worker__EnableSampleJob` live in **`api.env`** and are synced into `server-files/.env` by sync.

### 13.3 `web.env`

| Variable | Purpose |
|----------|---------|
| `TAG` / `REGISTRY` | Web image build/push |
| `WEB_HOST_PORT` | VPS port for web container |
| `NEXT_PUBLIC_API_URL` | API base URL in browser (build-time) |
| `NEXT_PUBLIC_WS_URL` | WebSocket URL (build-time) |
| `NEXT_PUBLIC_GOOGLE_CLIENT_ID` | Google Sign-In Web client ID (build-time; must match `Google__ClientId`) |
| `NEXT_PUBLIC_MAINTENANCE_MODE` | `true` = maintenance page |

### 13.4 Worker keys in `api.env`

| Variable | Purpose |
|----------|---------|
| `TAG` / `REGISTRY` | Worker image build/push |
| `Worker__PollIntervalSeconds` | Idle/sample job interval |
| `Worker__EnableSampleJob` | Demo background job |
| `Worker__EnableEmailDelivery` | SMTP consumer |
| `Worker__EnableSmsOtpDelivery` | SMS OTP consumer |
| `Scheduler__Enabled` | Quartz cron scheduler (UTC) |
| `Scheduler__Jobs__<Name>__Enabled` / `__Cron` | Per-job toggle / Quartz cron override (e.g. `Heartbeat`) |
| `Redis__*` / `Realtime__*` | Worker uses Redis for leaderboards and to push SignalR events via the backplane (see §7.5.1) |

---

## 14. Troubleshooting

| Symptom | Check |
|---------|--------|
| API won't start on VPS | `./health-check.sh`; `docker logs challingo-api`; JWT key length ≥ 32 |
| Worker crash loop / `Microsoft.AspNetCore.App` missing | Worker Dockerfile final stage must be `mcr.microsoft.com/dotnet/aspnet:10.0` (not `runtime`); rebuild with `.\build-and-push-worker.ps1` |
| Google Sign-In fails | `NEXT_PUBLIC_GOOGLE_CLIENT_ID` in web image; `Google__ClientId` in synced `.env`; VPS can reach `googleapis.com` |
| OTP never arrives | `Otp__LogOnly`, `RabbitMq__Enabled`, worker flags, `Email__Enabled` / `Sms__*` |
| OTP in logs only | Expected when `Otp__DevMode=true` or `Otp__LogOnly=true` |
| Web can't reach API / SSR errors | nginx upstream ports must match `docker ps` and `API_HOST_PORT`/`WEB_HOST_PORT` in api.env; use `proxy_pass http://{slug}_api` **without** trailing slash (ASP.NET routes include `/api/`); web container needs `API_INTERNAL_URL=http://challingo-api:8080` for SSR; `curl http://127.0.0.1:$API_HOST_PORT/health/ready` |
| Migrate errors | Run `dotnet ef database update` locally first; then `Database__AutoMigrate=true` on VPS |
| Port already in use | Change `API_HOST_PORT` / `POSTGRES_HOST_PORT` in `api.env`, re-sync |
| Rabbit not starting | Set `RabbitMq__Enabled=true` before `./server-up.sh` |
| 503 on all routes | `Maintenance__Enabled=true` or API not ready |
| 429 Too Many Requests | Lower client rate, or raise `RateLimit__GlobalPerMinute` / `Auth__OtpRateLimitPerMinute` in `api.env` → sync → restart |
| Requests aborting mid-flight | Raise `RequestTimeout__Seconds` or fix slow downstream; health paths are exempt |
| SMS provider flaky | Check `Http__*` retry/circuit; Worker logs for circuit-open; sms.ir credentials |
| sync changed nothing | Edit `api.env` not `server-files/.env` |

---

## 15. Checklist — first VPS deploy

- [ ] `api.env`: `REGISTRY`, `TAG`, JWT, Postgres, ports
- [ ] `web.env`: `NEXT_PUBLIC_API_URL`, `WEB_HOST_PORT`
- [ ] `api.env`: `TAG`, `REGISTRY`, `Worker__*`, review `RateLimit__*` / `RequestTimeout__*` / `Http__*`
- [ ] `.\sync-server-env.ps1` / `./sync-server-env.sh`
- [ ] Dev Docker insecure registry: `YOUR_VPS_IP:8585`
- [ ] VPS Docker insecure registry: `127.0.0.1:8585`
- [ ] `.\sync-server-env.ps1` (server `.env` has `127.0.0.1:8585` and full `*_IMAGE=` paths)
- [ ] `.\build-and-push-api.ps1` / `./build-and-push-all.sh` (+ web, worker)
- [ ] Copy `server-files/` to VPS
- [ ] `./server-up.sh` + `./health-check.sh`
- [ ] Confirm VPS `.env` has `Database__AutoMigrate=true` (set automatically by `sync-server-env`)
- [ ] `./backup-db.sh` test
- [ ] Enable Rabbit/email/SMS only when credentials are ready

---

## 16. Related docs

| Doc | Location |
|-----|----------|
| Deploy scripts detail | `README.md` (this folder) |
| cursor-scaffold toolkit | `cursor-scaffold/README.md` |
| macOS / Linux creator | `cursor-scaffold/docs/en/MACOS.md` |
| English onboarding | `cursor-scaffold/docs/en/ONBOARDING.md` |
| Persian onboarding | `cursor-scaffold/docs/fa/ONBOARDING.md` |
| Quick help | `cursor-scaffold/Help.ps1` / `help.sh` |
| Shared dev Postgres | `cursor-scaffold/dev-postgres/README.md` |
| API template notes | `challingo-api/README.md` |

When in doubt: **edit `api.env` → sync → build → `server-up.sh`**.
