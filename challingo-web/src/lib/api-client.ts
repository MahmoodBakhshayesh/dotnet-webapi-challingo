import { buildApiUrl } from "@/lib/env";
import type { AppResponse } from "@/lib/api-types";
import { useAuthStore } from "@/stores/auth-store";
import type { TokenResponse } from "@/types/api";

type FetchOptions = RequestInit & {
  skipAuth?: boolean;
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
    return {
      status: -res.status,
      message: "Invalid JSON response",
    };
  }
}

/** Refresh tokens via API; updates Zustand on success. */
async function tryRefresh(): Promise<boolean> {
  const { refreshToken, accessToken, setTokens, clearSession } =
    useAuthStore.getState();
  if (!refreshToken || !accessToken) return false;

  const body = JSON.stringify({
    token: accessToken,
    refreshToken,
  });

  const res = await fetch(buildApiUrl("/api/auth/refresh"), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body,
  });

  const env = await parseJson<{ token?: TokenResponse }>(res);
  const inner = env.body?.token;
  if (inner?.accessToken && inner.refreshToken) {
    setTokens(inner.accessToken, inner.refreshToken);
    return true;
  }
  clearSession();
  return false;
}

/**
 * JSON API call — sends Bearer token unless skipAuth.
 * On 401, attempts one token refresh and retries.
 */
export async function apiJson<T>(
  path: string,
  options: FetchOptions = {},
): Promise<AppResponse<T>> {
  const { skipAuth, headers, ...rest } = options;
  const token = useAuthStore.getState().accessToken;

  const exec = async (bearer: string | null) => {
    const h = new Headers(headers);
    h.set("Content-Type", "application/json");
    if (bearer && !skipAuth) h.set("Authorization", `Bearer ${bearer}`);
    return fetch(buildApiUrl(path), {
      ...rest,
      headers: h,
    });
  };

  let res = await exec(skipAuth ? null : token);

  if (res.status === 401 && !skipAuth && token) {
    const ok = await tryRefresh();
    if (ok) {
      const next = useAuthStore.getState().accessToken;
      res = await exec(next);
    }
  }

  return parseJson<T>(res);
}

/**
 * Authenticated GET returning raw bytes (e.g. file download).
 * On 401, attempts one token refresh and retries.
 */
export async function apiBlob(path: string): Promise<Blob> {
  const token = useAuthStore.getState().accessToken;

  const exec = async (bearer: string | null) => {
    const h = new Headers();
    if (bearer) h.set("Authorization", `Bearer ${bearer}`);
    return fetch(buildApiUrl(path), { method: "GET", headers: h });
  };

  let res = await exec(token);

  if (res.status === 401 && token) {
    const ok = await tryRefresh();
    if (ok) {
      const next = useAuthStore.getState().accessToken;
      res = await exec(next);
    }
  }

  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || res.statusText || "Download failed");
  }

  return res.blob();
}

/** Multipart upload — sets Authorization only (no Content-Type override). */
export async function apiForm<T>(
  path: string,
  formData: FormData,
  method: "POST" | "PUT" = "POST",
): Promise<AppResponse<T>> {
  const token = useAuthStore.getState().accessToken;
  const headers = new Headers();
  if (token) headers.set("Authorization", `Bearer ${token}`);

  let res = await fetch(buildApiUrl(path), {
    method,
    headers,
    body: formData,
  });

  if (res.status === 401 && token) {
    const ok = await tryRefresh();
    if (ok) {
      const next = useAuthStore.getState().accessToken;
      const h2 = new Headers();
      if (next) h2.set("Authorization", `Bearer ${next}`);
      res = await fetch(buildApiUrl(path), {
        method,
        headers: h2,
        body: formData,
      });
    }
  }

  return parseJson<T>(res);
}
