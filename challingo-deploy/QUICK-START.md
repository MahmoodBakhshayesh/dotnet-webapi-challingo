# Challingo — Quick start

One-page cheat sheet. Full details: [SETUP-GUIDE.md](./SETUP-GUIDE.md) · Deploy scripts: [README.md](./README.md)

---

## First time (new project)

```powershell
# Windows — from cursor-scaffold
.\New-Project.ps1 -ProjectName Challingo

# Local database (once per machine)
cd cursor-scaffold\dev-postgres
docker compose up -d
.\create-db.ps1 challingo

# Run locally
cd challingo-api
dotnet run --project Challingo.Api

cd ..\challingo-web
npm run dev                    # .env.local → http://localhost:5128

# Configure & deploy
cd ..\challingo-deploy
.\Set-PublishSettings.ps1 -Interactive   # domain, ports, nginx, REGISTRY, TAG
# Edit secrets in api.env (JWT, Postgres password, …)
.\build-and-push-all.ps1                 # builds + pushes + syncs server-files/.env
# Copy server-files/ to VPS → ./server-up.sh
```

```bash
# macOS / Linux — from cursor-scaffold (needs: brew install --cask powershell)
./install-api-template.sh
./new-project.sh -ProjectName Challingo

cd cursor-scaffold/dev-postgres && docker compose up -d && ./create-db.sh challingo
cd ../challingo/challingo-api && dotnet run --project Challingo.Api
cd ../challingo-deploy
./set-publish-settings.sh -Interactive
./build-and-push-all.sh
# Copy server-files/ to VPS → ./server-up.sh
```

---

## Daily commands

| Goal | Command |
|------|---------|
| Run API | `dotnet run --project Challingo.Api` |
| Run worker | `dotnet run --project Challingo.Worker` |
| Run web | `npm run dev` in `challingo-web` |
| Publish settings | `.\Set-PublishSettings.ps1 -Interactive` / `./set-publish-settings.sh -Interactive` |
| Build & push all | `.\build-and-push-all.ps1` / `./build-and-push-all.sh` |
| Sync VPS env only | `.\sync-server-env.ps1` / `./sync-server-env.sh` |
| Sync staging env | `.\sync-server-env-staging.ps1` / `./sync-server-env-staging.sh` |
| Deploy on VPS (prod) | `./server-up.sh` in `server-files/` |
| Deploy on VPS (staging) | `./server-up-staging.sh` in `server-files-staging/` |
| Promote staging → prod | `./promote-staging-to-prod.sh` (deploy folder) |
| Health check | `./health-check.sh` |
| Stop stack | `./server-down.sh` / `./server-down-staging.sh` |

---

## Configuration rules

```text
api.env   → runtime (API + worker): JWT, Postgres, RabbitMQ, SMS, Email, Serilog, Worker__*, RateLimit__/RequestTimeout__/Http__/Idempotency__
web.env   → build-time: NEXT_PUBLIC_* (rebuild web image after change)
          → sync-server-env.ps1 → server-files/.env → VPS containers
```

**Runtime change** (SMS, Gmail, Rabbit, Google client ID, log level, rate limits): edit `api.env` → `sync-server-env.ps1` → `./server-up.sh`  
**Web public URL or Google client ID change**: edit `web.env` → `build-and-push-web.ps1` → `./server-up.sh`

**Traffic resilience** (defaults in `api.env`): global rate limit + auth OTP limit, request timeouts, outbound HttpClient retry/circuit (SMS), optional `Idempotency-Key` (off by default). See [SETUP-GUIDE.md](./SETUP-GUIDE.md) §13.2.

---

## Google Sign-In (quick)

1. Google Cloud → OAuth **Web client** → add origins (`http://localhost:3000`, production domain).
2. `web.env`: `NEXT_PUBLIC_GOOGLE_CLIENT_ID=…` → rebuild web.
3. `api.env`: `Google__ClientId=…` (same Web ID) → sync → `./server-up.sh` (recreates api/web/worker).
4. On VPS: `docker exec challingo-api printenv Google__ClientId`

See [SETUP-GUIDE.md](./SETUP-GUIDE.md) §7.3 for full checklist.

---

## Enable production OTP (SMS + email)

Edit **`api.env`**:

```env
RabbitMq__Enabled=true
Otp__DevMode=false
Otp__LogOnly=false
Email__Enabled=true
Email__SmtpUsername=...
Email__SmtpPassword=...
Worker__EnableEmailDelivery=true
Sms__Provider=SmsIr
Sms__SmsIrApiKey=...
Worker__EnableSmsOtpDelivery=true
```

Then: `.\sync-server-env.ps1` → copy `server-files/` if needed → `./server-up.sh`

---

## Default ports (change in api.env / web.env if busy)

| Service | Host port |
|---------|-----------|
| Postgres | `5434` |
| API | `8080` |
| Web | `3000` |
| Registry (VPS) | `8585` |

Local dev Postgres: `127.0.0.1:5434` · API (Kestrel): `5128` · Web dev: `3000`

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| API exits on startup | Check `docker logs challingo-api` — DB/migrate; API keeps running on seed errors |
| 502 on login | API container down — `docker ps`, `./server-up.sh` |
| 429 Too Many Requests | Raise `RateLimit__GlobalPerMinute` or `Auth__OtpRateLimitPerMinute` in `api.env` → sync → restart |
| Web can't reach API in Docker | SSR uses `API_INTERNAL_URL` in compose; browser uses `NEXT_PUBLIC_API_URL` |
| Push timeout to registry | Docker Desktop → insecure-registries → `YOUR_VPS:8585` |
| `$'\r'` on VPS | `sed -i 's/\r$//' .env *.sh` |

---

## Architecture (one VPS project)

```text
Internet → nginx (:443)
              ├─ /              → web :3000
              ├─ /api/          → api :8080
              staging.{domain}/     → staging web :3001
              staging.{domain}/api/ → staging api :8081
              (no domain: IP:81 → staging)
                ↓
         challingo-network          (+ …-staging-network)
         postgres · api · web · worker · (rabbitmq)
```

Worker shares **`api.env`** — no separate worker.env.

---

## Staging (same domain, path twin)

No extra DNS. Same images as production; separate DB/volumes.

| | Production | Staging |
|--|------------|---------|
| Web | `https://{domain}/` | `https://staging.{domain}/` |
| API | `https://{domain}/api/` | `https://staging.{domain}/api/` |
| IP (no DNS) | `http://IP/` (:80) | `http://IP:81/` |
| Folder | `server-files/` | `server-files-staging/` |

```powershell
.\sync-server-env.ps1
.\sync-server-env-staging.ps1
.\build-and-push-all.ps1
# Copy both server-files/ and server-files-staging/ to VPS
```

```bash
# On VPS
cd server-files-staging && chmod +x *.sh && ./server-up-staging.sh   # QA at staging.{domain} or :81
# After OK:
cd ../ && ./promote-staging-to-prod.sh                               # same TAG → :latest + server-up
```
