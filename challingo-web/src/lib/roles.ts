/**
 * Role helpers aligned with the API (`Admin`, `Member`, optional `Operator` / `Supervisor`).
 */

import {
  features,
  organizationsEnabled,
  supervisorsEnabled,
} from "@/config/features";

export function normalizedRoleSet(roles: readonly string[]): Set<string> {
  return new Set(
    roles.map((r) => String(r).trim().toLowerCase()).filter(Boolean),
  );
}

export function isAdminRole(roles: readonly string[]): boolean {
  return normalizedRoleSet(roles).has("admin");
}

export function isMemberRole(roles: readonly string[]): boolean {
  const s = normalizedRoleSet(roles);
  return s.has("member") || s.has("user");
}

export function isOperatorRole(roles: readonly string[]): boolean {
  return normalizedRoleSet(roles).has("operator");
}

export function isSupervisorRole(roles: readonly string[]): boolean {
  return normalizedRoleSet(roles).has("supervisor");
}

/** Where to send the user immediately after login. */
export function getPostLoginRoute(roles: readonly string[]): string {
  if (isAdminRole(roles)) return "/dashboard";
  if (supervisorsEnabled() && isSupervisorRole(roles) && features.operatorPanel) {
    return "/ops";
  }
  if (features.operatorPanel && isOperatorRole(roles)) return "/ops";
  if (features.userPanel && isMemberRole(roles)) return "/account";
  if (features.operatorPanel) return "/ops";
  return "/dashboard";
}

export { organizationsEnabled, supervisorsEnabled };
