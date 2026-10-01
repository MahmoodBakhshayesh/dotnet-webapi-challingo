/** Google OAuth Web client ID for Sign-In button (must match API Google__ClientId list). */
export function getGoogleClientId(): string | undefined {
  const id = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID?.trim();
  return id || undefined;
}

/**
 * Browser-safe public env (must be prefixed NEXT_PUBLIC_).
 * Production and staging are separate hosts — both use same-origin `/api`.
 */
export function getApiBaseUrl(): string {
  // Docker SSR: call API on the compose network (avoids hairpin NAT via public domain).
  const internal = process.env.API_INTERNAL_URL?.replace(/\/$/, "");
  if (typeof window === "undefined" && internal) {
    return internal;
  }

  const url = process.env.NEXT_PUBLIC_API_URL?.replace(/\/$/, "");
  if (!url) {
    if (typeof window !== "undefined") {
      return "/api";
    }
    console.warn("NEXT_PUBLIC_API_URL is unset; using http://localhost:5128");
    return "http://localhost:5128";
  }
  if (/^http:\/\/(?:localhost|127\.0\.0\.1):44390/i.test(url)) {
    console.warn(
      "NEXT_PUBLIC_API_URL uses http on port 44390; IIS Express requires https://localhost:44390",
    );
  }
  return url;
}

/** Site origin without a trailing `/api` (for /uploads/ and other non-API static paths). */
export function getSiteOrigin(): string {
  const base = getApiBaseUrl();
  return /\/api$/i.test(base) ? base.replace(/\/api$/i, "") : base;
}

/**
 * Join API base with a path when NEXT_PUBLIC_API_URL ends with `/api`.
 * Example: base `https://example.com/api` + path `/api/auth/login` → `…/api/auth/login`
 */
export function buildApiUrl(path: string): string {
  const base = getApiBaseUrl();
  const normalized = path.startsWith("/") ? path : `/${path}`;

  if (/\/api$/i.test(base) && normalized.startsWith("/api/")) {
    return `${base}${normalized.slice(4)}`;
  }
  if (/\/api$/i.test(base) && normalized === "/api") {
    return base;
  }
  return `${base}${normalized}`;
}

/** Resolve API-hosted media paths (avatars, uploads) for dev and /api-prefixed production URLs. */
export function resolveMediaUrl(relativeOrAbsolute?: string | null): string | undefined {
  if (!relativeOrAbsolute) return undefined;
  if (/^https?:\/\//i.test(relativeOrAbsolute)) return relativeOrAbsolute;
  const path = relativeOrAbsolute.startsWith("/") ? relativeOrAbsolute : `/${relativeOrAbsolute}`;
  if (path.startsWith("/uploads/")) {
    return `${getSiteOrigin()}${path}`;
  }
  return buildApiUrl(path);
}

/** Origin for SignalR (same host/port as API). */
export function getWsBaseUrl(): string {
  const url = process.env.NEXT_PUBLIC_WS_URL?.replace(/\/$/, "");
  return url ?? getApiBaseUrl();
}

/**
 * Map tile layer config (Leaflet).
 * Set these for Map.ir (or any provider) without code changes.
 */
export function getMapTileUrl(): string {
  const raw =
    process.env.NEXT_PUBLIC_MAP_TILE_URL ??
    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png";
  const key = process.env.NEXT_PUBLIC_MAP_API_KEY ?? "";
  return raw.replaceAll("{mapApiKey}", encodeURIComponent(key));
}

export function getMapTileAttribution(): string {
  const raw =
    process.env.NEXT_PUBLIC_MAP_TILE_ATTRIBUTION ??
    '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>';
  const key = process.env.NEXT_PUBLIC_MAP_API_KEY ?? "";
  return raw.replaceAll("{mapApiKey}", encodeURIComponent(key));
}

export function getMapUseWms(): boolean {
  return String(process.env.NEXT_PUBLIC_MAP_USE_WMS ?? "").toLowerCase() === "true";
}

export function getMapWmsLayers(): string {
  return process.env.NEXT_PUBLIC_MAP_WMS_LAYERS ?? "Shiveh:ShivehGSLD256";
}

export function getMapWmsFormat(): string {
  return process.env.NEXT_PUBLIC_MAP_WMS_FORMAT ?? "image/png";
}
