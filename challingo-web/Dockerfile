# Production Next.js (standalone). NEXT_PUBLIC_* are baked at build time - pass via --build-arg.

FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:22-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ARG NEXT_PUBLIC_API_URL=http://localhost:8080
ARG NEXT_PUBLIC_WS_URL=http://localhost:8080
ARG NEXT_PUBLIC_MAP_API_KEY=
ARG NEXT_PUBLIC_MAP_USE_WMS=false
ARG NEXT_PUBLIC_MAP_TILE_URL=
ARG NEXT_PUBLIC_MAP_TILE_ATTRIBUTION=
ARG NEXT_PUBLIC_MAP_WMS_LAYERS=
ARG NEXT_PUBLIC_MAP_WMS_FORMAT=
ARG NEXT_PUBLIC_MAINTENANCE_MODE=false
ARG NEXT_PUBLIC_GOOGLE_CLIENT_ID=
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_WS_URL=$NEXT_PUBLIC_WS_URL
ENV NEXT_PUBLIC_MAP_API_KEY=$NEXT_PUBLIC_MAP_API_KEY
ENV NEXT_PUBLIC_MAP_USE_WMS=$NEXT_PUBLIC_MAP_USE_WMS
ENV NEXT_PUBLIC_MAP_TILE_URL=$NEXT_PUBLIC_MAP_TILE_URL
ENV NEXT_PUBLIC_MAP_TILE_ATTRIBUTION=$NEXT_PUBLIC_MAP_TILE_ATTRIBUTION
ENV NEXT_PUBLIC_MAP_WMS_LAYERS=$NEXT_PUBLIC_MAP_WMS_LAYERS
ENV NEXT_PUBLIC_MAP_WMS_FORMAT=$NEXT_PUBLIC_MAP_WMS_FORMAT
ENV NEXT_PUBLIC_MAINTENANCE_MODE=$NEXT_PUBLIC_MAINTENANCE_MODE
ENV NEXT_PUBLIC_GOOGLE_CLIENT_ID=$NEXT_PUBLIC_GOOGLE_CLIENT_ID

RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=5 \
  CMD wget -qO- http://127.0.0.1:3000/ >/dev/null || exit 1

CMD ["node", "server.js"]
