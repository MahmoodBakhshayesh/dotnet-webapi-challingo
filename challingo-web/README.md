# Web (Next.js)

Next.js frontend for the scaffold stack (App Router, SSR, Tailwind).

## Local development

```bash
npm install
npm run dev
```

Default API URL in **`.env.local`**: `http://127.0.0.1:5128` (matches Kestrel / GUI Local Dev).

For Visual Studio IIS Express, use `https://localhost:44390` instead.

Open [http://localhost:3000](http://localhost:3000).

## API client

With the API running:

```bash
npm run generate-api-client
```

Regenerates `src/lib/api-schema.ts` from OpenAPI.

## Environment

| Variable | Dev | Production |
|----------|-----|------------|
| `NEXT_PUBLIC_API_URL` | `.env.local` | `{project}-deploy/web.env` → Docker build arg |
| `API_INTERNAL_URL` | — | Set in compose for SSR (`http://{kebab}-api:8080`) |

See `src/lib/env.ts`. Production `NEXT_PUBLIC_API_URL` should usually end with `/api`.

## Production

Build and push from **`{project}-deploy/build-and-push-web.ps1`**. Any change to `NEXT_PUBLIC_*` requires a **web image rebuild**.

Deploy docs: **`{project}-deploy/QUICK-START.md`** and **`SETUP-GUIDE.md`**.
