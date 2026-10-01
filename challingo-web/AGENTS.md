<!-- scaffold:web:start -->
# Challingo Web

Stack: Next.js (App Router) + Tailwind v4 + `motion` (`motion/react`).

- Public env: `NEXT_PUBLIC_*` in `.env.local`
- API base URL: configure for IIS Express or Kestrel (see `.env.example`)
- Deploy: `challingo-deploy/web.env` bakes `NEXT_PUBLIC_*` into Docker image
- UI motion / dense forms: see `.cursor/rules/web-ui-motion.mdc`, `web-forms-density.mdc`,
  `web-advanced-interactions.mdc`, and `web-icons.mdc` (shipped with the web template)
- New CRUD features mirror the `users` / `roles` / `organizations` / `auth` feature shape:
  `repositories/` (transport only) → `usecases/` (one per file) → `controllers/` (owns state,
  orchestrates via React Query) → `views/` (presentational only). See `ARCHITECTURE.md`.

Run: `npm run dev` from this folder.
<!-- scaffold:web:end -->
