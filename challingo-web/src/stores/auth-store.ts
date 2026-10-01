"use client";

import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";
import { mergeRolesFromJwt } from "@/lib/jwt-roles";
import type { UserLoginResponse } from "@/types/api";

type AuthState = {
  accessToken: string | null;
  refreshToken: string | null;
  username: string | null;
  email: string | null;
  roles: string[];
  setSession: (login: UserLoginResponse) => void;
  setTokens: (accessToken: string, refreshToken: string) => void;
  clearSession: () => void;
};

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      accessToken: null,
      refreshToken: null,
      username: null,
      email: null,
      roles: [],
      setSession: (login) => {
        const fromLogin = Array.isArray(login.roles)
          ? [...login.roles]
          : [];
        const roles = mergeRolesFromJwt(fromLogin, login.token.accessToken);
        set({
          username: login.username,
          email: login.email ?? null,
          roles,
          accessToken: login.token.accessToken,
          refreshToken: login.token.refreshToken,
        });
      },
      setTokens: (accessToken, refreshToken) =>
        set((state) => ({
          accessToken,
          refreshToken,
          roles: mergeRolesFromJwt(state.roles, accessToken),
        })),
      clearSession: () =>
        set({
          accessToken: null,
          refreshToken: null,
          username: null,
          email: null,
          roles: [],
        }),
    }),
    {
      name: "web-app-auth",
      storage: createJSONStorage(() => localStorage),
      partialize: (s) => ({
        accessToken: s.accessToken,
        refreshToken: s.refreshToken,
        username: s.username,
        email: s.email,
        roles: s.roles,
      }),
    },
  ),
);
