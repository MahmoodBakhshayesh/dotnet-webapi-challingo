import http from "node:http";
import https from "node:https";
import { getApiBaseUrl } from "@/lib/env";

type DevFetchInit = RequestInit & {
  next?: { revalidate?: number | false };
};

function isDev(): boolean {
  return process.env.NODE_ENV !== "production";
}

function isInternalDockerApi(url: string): boolean {
  try {
    const { hostname } = new URL(url);
    return hostname.endsWith("-api");
  } catch {
    return false;
  }
}

function isLocalApiHost(url: string): boolean {
  try {
    const { hostname } = new URL(url);
    return hostname === "localhost" || hostname === "127.0.0.1";
  } catch {
    return false;
  }
}

/** True when the configured API is local HTTPS (IIS Express / dev cert). */
export function isLocalDevHttpsApi(url?: string): boolean {
  if (!isDev()) return false;
  try {
    const { protocol, hostname } = new URL(url ?? getApiBaseUrl());
    return (
      protocol === "https:" &&
      (hostname === "localhost" || hostname === "127.0.0.1")
    );
  } catch {
    return false;
  }
}

function nodeFetch(input: string, init?: RequestInit): Promise<Response> {
  return new Promise((resolve, reject) => {
    const url = new URL(input);
    const isHttps = url.protocol === "https:";
    const lib = isHttps ? https : http;

    const headers: Record<string, string> = {};
    if (init?.headers) {
      new Headers(init.headers).forEach((value, key) => {
        headers[key] = value;
      });
    }

    const agent =
      isHttps && isLocalDevHttpsApi(input)
        ? new https.Agent({ rejectUnauthorized: false })
        : undefined;

    const req = lib.request(
      {
        protocol: url.protocol,
        hostname: url.hostname,
        port: url.port || (isHttps ? 443 : 80),
        path: `${url.pathname}${url.search}`,
        method: init?.method ?? "GET",
        headers,
        agent,
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () => {
          const responseHeaders = new Headers();
          for (const [key, value] of Object.entries(res.headers)) {
            if (value == null) continue;
            if (Array.isArray(value)) {
              value.forEach((v) => responseHeaders.append(key, v));
            } else {
              responseHeaders.set(key, value);
            }
          }
          resolve(
            new Response(Buffer.concat(chunks), {
              status: res.statusCode ?? 500,
              statusText: res.statusMessage,
              headers: responseHeaders,
            }),
          );
        });
      },
    );

    req.on("error", reject);

    if (init?.body) {
      if (typeof init.body === "string") {
        req.write(init.body);
      } else if (init.body instanceof Uint8Array) {
        req.write(init.body);
      } else {
        reject(new Error("Unsupported request body type"));
        return;
      }
    }

    req.end();
  });
}

/**
 * Server-side fetch for the API.
 * Routes local HTTPS dev certs and Docker internal API hosts through Node http(s).
 */
export async function devApiFetch(
  input: string,
  init?: DevFetchInit,
): Promise<Response | null> {
  const { next: _next, ...fetchInit } = init ?? {};

  try {
    if (
      (isDev() && isLocalApiHost(input)) ||
      isInternalDockerApi(input)
    ) {
      return await nodeFetch(input, fetchInit);
    }
    return await fetch(input, init);
  } catch (error) {
    console.error("[devApiFetch]", input, error);
    return null;
  }
}
