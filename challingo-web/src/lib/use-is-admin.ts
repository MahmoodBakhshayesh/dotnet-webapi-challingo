"use client";

import { mergeRolesFromJwt } from "@/lib/jwt-roles";
import { useAuthStore } from "@/stores/auth-store";

/** Admin UI gate — must match API (`[Authorize(Roles = Admin)]`): roles from login + JWT only. */
export function useIsAdmin(): boolean {
  const accessToken = useAuthStore((s) => s.accessToken);
  const persistedRoles = useAuthStore((s) => s.roles);

  const roles = mergeRolesFromJwt(persistedRoles, accessToken);
  return roles.some((r) => /^admin$/i.test(String(r).trim()));
}
