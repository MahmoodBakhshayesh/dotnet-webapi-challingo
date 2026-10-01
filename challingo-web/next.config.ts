import type { NextConfig } from "next";

/**
 * Browser uses NEXT_PUBLIC_API_URL=/api (same-origin).
 * IP:port access is proxied at runtime by src/app/api/[[...path]]/route.ts
 * (API_INTERNAL_URL from compose).
 *
 * Production and staging are separate hosts (or edge :80 / :81) — no path prefix.
 */
const nextConfig: NextConfig = {
  reactCompiler: true,
  /** Slim runtime image when using `deploy/docker` Dockerfile (standalone server). */
  output: "standalone",
};

export default nextConfig;
