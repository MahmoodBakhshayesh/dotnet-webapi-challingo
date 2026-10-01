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

## Challingo: players and puzzle engine

- **Players.** `PlayerProfile` (1:1 with `AppUser`) holds display name, guest flag, IANA `TimeZoneId` and the `CountryCode` derived from it (`Core/Players/PlayerTimeZones`, NodaTime tzdb — never IP). Zone changes: once per 30 days, effective from the next local midnight (`PlayerProfileRules.EffectiveTimeZone`). Always compute a player's "today" on the server.
- **Accounts.** `POST /api/auth/guest` creates a guest; `/api/me/email/request` + `/confirm` attach an email to the same account (progress kept). Normal email sign-up/sign-in is the scaffold's `/api/auth/register/email` and `/api/auth/otp/*`. `RequireUniqueEmail` is off because guests have no email; flows check `FindByEmailAsync` themselves.
- **Engine contract.** A game is an `IPuzzleGame` (`Core/Puzzles`): deterministic `GenerateAsync(seed, difficulty)` → public JSON (sent to the app) + secret JSON (never leaves the server), and `Verify(PuzzleSubmission)` returning `Solved`, `Incorrect` (wrong answer: attempt stays open, clock runs), `Failed` (attempt over) or `Invalid` (malformed, nothing recorded). Games whose answer the app may not hold (Code Breaker, Word Guess, Mine Logic) or with per-move time limits (Word Hunt) are `IInteractivePuzzleGame`: `ApplyMove` returns the new state (stored on the attempt, returned on resume, so **never secrets**), the reply, and optionally an outcome. Register generated games as singletons and content games as scoped in `Api/DependencyInjection.cs`; `IPuzzleGameRegistry` (scoped) finds them by `Key`. Bump `GeneratorVersion` when output changes.
- **Games (Stage 1).** `sudoku`, `kakuro`, `nonogram` (unique solutions, checked by solvers), `path-link` (any valid fill), `mine-logic` (no-guess boards, server reveals), `code-breaker`, `number-merge` (shared `mulberry32` seed — the app must use the identical spawn rule documented in `NumberMergeGame`), `word-hunt` and `word-guess` (need the word list at `Words__DictionaryPath`), `mini-crossword` and `word-guess` answers (reviewed content).
- **Reviewed content.** `PuzzleContent` rows (`Draft` → `Approved` → `Retired`) per game, validated by an `IPuzzleContentValidator`. Admin API: `/api/admin/content/{game}`, `/content/word-guess/bulk`, `/content/items/{id}/approve|retire`, and `/api/admin/puzzles/{game}/preview` (solution included).
- **Attempts.** `POST /api/challenges/{id}/start` records server start time and returns the public puzzle + an HMAC attempt token (+ `interactive`, and `state` on resume); restarting resumes the same attempt (clock keeps running). Interactive games send `POST /api/challenges/attempts/{id}/move`. `POST …/submit` verifies on the server; elapsed = server submit − server start. One attempt per player per challenge (unique index); `MoveCount` is the optimistic-concurrency token for state, and completion is a conditional update so only one request wins.
- **Practice.** `POST /api/challenges/practice/{gameKey}` makes an owner-only, unranked challenge — the quickest way to exercise a new game end to end.
