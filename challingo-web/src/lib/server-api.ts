import { buildApiUrl } from "@/lib/env";
import { devApiFetch } from "@/lib/dev-api-fetch";
import type { AppResponse } from "@/lib/api-types";

type ServerFetchOptions = RequestInit & {
  token?: string;
  revalidate?: number | false;
};

async function parseJson<T>(res: Response): Promise<AppResponse<T>> {
  const text = await res.text();
  if (!text) {
    return {
      status: res.ok ? res.status : -res.status,
      message: res.statusText || "Empty response",
    };
  }
  try {
    return JSON.parse(text) as AppResponse<T>;
  } catch {
    return { status: -res.status, message: "Invalid JSON response" };
  }
}

/** Server-side fetch for RSC — no Zustand, no client auth refresh. */
export async function serverApiFetch<T>(
  path: string,
  options: ServerFetchOptions = {},
): Promise<AppResponse<T>> {
  const { token, revalidate = false, headers, ...rest } = options;
  const h = new Headers(headers);
  h.set("Content-Type", "application/json");
  if (token) h.set("Authorization", `Bearer ${token}`);

  const res = await devApiFetch(buildApiUrl(path), {
    ...rest,
    headers: h,
    cache: "no-store",
    next: revalidate === false ? { revalidate: 0 } : { revalidate },
  });
  if (!res) {
    return { status: -1, message: "Network error" };
  }

  return parseJson<T>(res);
}

export async function serverApiGet<T>(
  path: string,
  options?: Omit<ServerFetchOptions, "method" | "body">,
): Promise<T | null> {
  const res = await serverApiFetch<T>(path, { ...options, method: "GET" });
  if (res.status > 0 && res.status < 400 && res.body != null) return res.body;
  return null;
}
