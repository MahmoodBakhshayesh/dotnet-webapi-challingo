/**
 * Data source: API auth endpoints.
 * No business rules — transport only.
 */
import { apiJson } from "@/lib/api-client";
import type { AppResponse } from "@/lib/api-types";
import type { UserLoginResponse } from "@/types/api";

export const authRepository = {
  loginPassword(username: string, password: string) {
    return apiJson<UserLoginResponse>("/api/auth/login", {
      method: "POST",
      skipAuth: true,
      body: JSON.stringify({ username, password }),
    });
  },

  loginGoogle(idToken: string) {
    return apiJson<UserLoginResponse>("/api/auth/google", {
      method: "POST",
      skipAuth: true,
      body: JSON.stringify({ idToken }),
    });
  },

  requestOtp(email: string) {
    return apiJson<{ message?: string }>("/api/auth/otp/request", {
      method: "POST",
      skipAuth: true,
      body: JSON.stringify({ email }),
    });
  },

  verifyOtp(email: string, code: string) {
    return apiJson<UserLoginResponse>("/api/auth/otp/verify", {
      method: "POST",
      skipAuth: true,
      body: JSON.stringify({ email, code }),
    });
  },

  logout(): Promise<AppResponse<unknown>> {
    return apiJson<unknown>("/api/auth/logout", { method: "POST" });
  },
};
