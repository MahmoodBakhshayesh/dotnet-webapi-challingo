# Challingo monorepo

| Folder | Purpose |
|--------|---------|
| challingo-api | Challingo ASP.NET Core API |
| challingo-api/Challingo.Worker | Background worker host (same repo folder as API) |
| challingo-web | Next.js web |
| challingo-app | Flutter app |
| challingo-deploy | Docker build/push + VPS server-files |

Open `challingo.code-workspace` in VS Code/Cursor for multi-root editing.

## API / Worker ops notes

- Keep **one API replica** while `Database:AutoMigrate=true` (default on first VPS boot). Concurrent `MigrateAsync` from multiple replicas is unsafe. For multi-replica, set `Database__AutoMigrate=false` and apply migrations out-of-band (CI/CD or `dotnet ef database update`).
- Seed admin email/password come from `Auth__SeedAdminEmail` / `Auth__SeedAdminPassword` (set at project create into `.env` / `api.env`). Production rejects known placeholders.
- Worker waits for schema (`AspNetUsers` / `__EFMigrationsHistory`), not only DB connectivity.