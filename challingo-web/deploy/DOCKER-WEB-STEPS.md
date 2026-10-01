# Web app — Docker steps (web only)

Build and run the Next.js image from the project web folder.

```powershell
cd path/to/your-project-web
docker build -t your-project-web:latest .
docker run -d --name your-project-web -p 3000:3000 your-project-web:latest
```

For production deploy, use `{project}-deploy/` scripts and VPS `server-up.sh`.
