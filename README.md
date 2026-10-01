# Challingo

Monorepo scaffolded with **New-Project.ps1**.

| Folder | Stack |
|--------|-------|
| **challingo-api/** | ASP.NET Core - `Challingo.Api` + `Challingo.Worker` (background host) |
| **challingo-web/** | Next.js |
| **challingo-app/** | Flutter |
| **challingo-deploy/** | Docker deploy |

Folders: `challingo-api`, `challingo-web`, `challingo-app`, `challingo-deploy`. Docker network: `challingo-network`.

## Docs (start here)

| File | Purpose |
|------|---------|
| `challingo-deploy/QUICK-START.md` | Daily commands (English) |
| `challingo-deploy/QUICK-START.fa.md` | Daily commands (Persian) |
| `challingo-deploy/SETUP-GUIDE.md` | Full setup and configuration |
| `challingo-deploy/README.md` | Deploy scripts reference |

## Quick start

```powershell
# Local
cd challingo-api
dotnet run --project Challingo.Api

dotnet run --project Challingo.Worker

cd ..\challingo-web
npm run dev

# Deploy
cd ..\challingo-deploy
.\Set-PublishSettings.ps1 -Interactive
.\build-and-push-all.ps1
# copy server-files/ to VPS → ./server-up.sh
```

## Flutter feature

```powershell
cd challingo-app
mason make "mbkh_feat" --feature_name my_feature --entity_name MyEntity --usecase_action get -o .
```

Rules from `/Users/ezio/FullProjects/cursor-scaffold/rules`.