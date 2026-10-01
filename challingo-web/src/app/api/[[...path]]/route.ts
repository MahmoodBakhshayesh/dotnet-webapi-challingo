import type { NextRequest } from "next/server";

/**
 * Runtime reverse-proxy for NEXT_PUBLIC_API_URL=/api when there is no nginx in front
 * (e.g. http://IP:WEB_PORT/api/...). Uses API_INTERNAL_URL from compose at request time.
 *
 * With domain nginx, /api is handled at the edge and this route is never hit.
 */
export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const HOP_BY_HOP = new Set([
  "connection",
  "keep-alive",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailers",
  "transfer-encoding",
  "upgrade",
  "host",
  "content-length",
]);

type RouteContext = { params: Promise<{ path?: string[] }> };

async function proxyToApi(req: NextRequest, pathParts: string[]) {
  const base = (process.env.API_INTERNAL_URL || "http://127.0.0.1:8080").replace(/\/$/, "");
  const sub = (pathParts ?? []).join("/");
  const target = `${base}/api/${sub}${req.nextUrl.search}`;

  const headers = new Headers();
  req.headers.forEach((value, key) => {
    if (!HOP_BY_HOP.has(key.toLowerCase())) {
      headers.set(key, value);
    }
  });
  const host = req.headers.get("host");
  if (host) headers.set("x-forwarded-host", host);
  headers.set("x-forwarded-proto", req.nextUrl.protocol.replace(":", "") || "http");

  const init: RequestInit & { duplex?: "half" } = {
    method: req.method,
    headers,
    redirect: "manual",
  };

  if (req.method !== "GET" && req.method !== "HEAD") {
    init.body = await req.arrayBuffer();
  }

  let upstream: Response;
  try {
    upstream = await fetch(target, init);
  } catch (err) {
    return Response.json(
      {
        error: "API proxy unreachable",
        target,
        detail: err instanceof Error ? err.message : String(err),
      },
      { status: 502 },
    );
  }

  const out = new Headers();
  upstream.headers.forEach((value, key) => {
    if (!HOP_BY_HOP.has(key.toLowerCase())) {
      out.set(key, value);
    }
  });

  return new Response(upstream.body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers: out,
  });
}

async function handle(req: NextRequest, ctx: RouteContext) {
  const { path } = await ctx.params;
  return proxyToApi(req, path ?? []);
}

export const GET = handle;
export const POST = handle;
export const PUT = handle;
export const PATCH = handle;
export const DELETE = handle;
export const OPTIONS = handle;
export const HEAD = handle;
