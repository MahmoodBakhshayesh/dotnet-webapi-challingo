<!-- scaffold:api:start -->
# Agent guide — Stack API template

Layered ASP.NET Core API. Align new code with existing **Organization**, **Users**, and **Auth** flows.

## Projects

1. **`Challingo.Api`** — Controllers, `DependencyInjection`, middleware, Swagger. Controllers inherit **`AppController`**. Inject **service interfaces only**.
2. **`Challingo.Core`** — Domain entities, **`I*Repository`** / **`I*Service`**, DTOs, **`AppResponse`** in services, settings under `Settings/`.
3. **`Challingo.Infrastructure`** — **`AppDbContext`**, EF configurations, repository implementations, email/SMS/RabbitMQ, `Http/ScaffoldHttpResilienceExtensions`.

The **`Challingo`** token is replaced when scaffolding (copy + rename to your Pascal name).

## Host pipeline & resilience

Wired in `Extensions/ScaffoldHostExtensions.cs` + `Program.cs`:

- **Rate limiting** — global (`RateLimit__*`) after auth so partitions can use user id; policy `auth-otp` on `AuthController`.
- **Request timeouts** — `RequestTimeout__*` (type `ScaffoldRequestTimeoutOptions`); health checks call `DisableRequestTimeout()`.
- **Idempotency** — `IdempotencyMiddleware` when `Idempotency__Enabled=true` (header default `Idempotency-Key`).
- **Outbound HTTP** — Worker SMS registers `AddScaffoldHttpResilience` from `Http__*`.

Do not bypass these for new mutating endpoints without a reason. Prefer env toggles over hard-coding limits.

See **`.cursor/rules/`** and deploy **SETUP-GUIDE.md** §7.5.

## Redis, realtime, scheduler

Toggled by env, wired in `Program.cs` (`AddScaffoldRedis`, `AddScaffoldRealtime`, `MapScaffoldRealtime`) and `Worker/Program.cs` (`AddWorkerScheduler`).

- **`ILeaderboardStore`** (Core) — ranked boards. `RedisLeaderboardStore` (sorted sets, `Redis__Enabled=true`) or `InMemoryLeaderboardStore`. Postgres stays the source of truth; snapshot boards when a period closes, `ExpireAsync` old ones.
- **`IRealtimeNotifier`** (Core) — push to `ToUserAsync` / `ToGroupAsync` / `ToAllAsync`. Hub: `Infrastructure/Realtime/AppHub.cs` at `Realtime__HubPath` (`/hubs/app`), `[Authorize]`, JWT via `?access_token=`. The hub type lives in Infrastructure so the Worker can publish through the Redis backplane — do not move it into Api.
- **Hub topics** — clients call `Subscribe("challenge:{id}")`; lowercase `[a-z0-9:_-.]`, `user:*` reserved. Keep hub methods thin; real work goes through services/controllers.
- **Quartz (Worker)** — add jobs as `IJob` (`ValueTask Execute(context, ct)`, `[DisallowConcurrentExecution]`) and register with `q.AddScaffoldJob<TJob>(scheduler, "Name", "<quartz cron UTC>")`. In-memory store: single Worker replica, idempotent jobs.
- Never trust client clocks for gameplay timing: use server UTC (`AppHub.Ping`, API timestamps).
<!-- scaffold:api:end -->

<!-- scaffold:worker:start -->
# Challingo Worker

Background job host for Challingo (no public HTTP). Lives inside **challingo-api/Challingo.Worker**.

- Shares **Core** + **Infrastructure** with the API solution
- Local config: **challingo-api/.env** (DotNetEnv; includes `Worker__*` and **`Http__*`** keys)
- Deploy: `challingo-deploy/api.env` + `build-and-push-worker.ps1` / `.sh`
- Docker: `challingo-worker` on `challingo-network` (final image: `mcr.microsoft.com/dotnet/aspnet:10.0`)

## SMS HttpClient resilience

When sms.ir delivery is enabled, `SmsIrSmsSender` uses `AddScaffoldHttpResilience` bound to **`Http__*`** (`TimeoutSeconds`, `RetryCount`, exponential backoff + jitter, circuit breaker). Toggle with `Http__Enabled=false` if needed.

Run locally:

```powershell
cd challingo-api
dotnet run --project Challingo.Worker
```

Replace `SampleBackgroundJob` with real queue/webhook/scheduled work.
<!-- scaffold:worker:end -->
