/**
 * Read role claims from an access JWT (no signature verification).
 * Handles Microsoft Identity claim URIs, short `role`, and role arrays.
 */
function decodeJwtPayload(token: string): Record<string, unknown> | null {
  try {
    const parts = token.split(".");
    if (parts.length < 2) return null;
    let base64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const pad = base64.length % 4;
    if (pad) base64 += "=".repeat(4 - pad);
    if (typeof atob !== "function") return null;
    const json = atob(base64);
    return JSON.parse(json) as Record<string, unknown>;
  } catch {
    return null;
  }
}

function isRoleClaimKey(key: string): boolean {
  const k = key.toLowerCase();
  return (
    k === "role" ||
    k.endsWith("/role") ||
    k.includes("claims/role") ||
    k.includes("identity/claims/role")
  );
}

function addRoleValue(roles: Set<string>, val: unknown): void {
  if (val === null || val === undefined) return;
  if (typeof val === "string") roles.add(val);
  else if (typeof val === "number") roles.add(String(val));
  else if (Array.isArray(val)) val.forEach((v) => addRoleValue(roles, v));
}

export function parseRolesFromJwt(accessToken: string | null): string[] {
  if (!accessToken) return [];
  const payload = decodeJwtPayload(accessToken);
  if (!payload) return [];
  const roles = new Set<string>();
  for (const [key, val] of Object.entries(payload)) {
    if (!isRoleClaimKey(key)) continue;
    addRoleValue(roles, val);
  }
  return [...roles];
}

export function mergeRolesFromJwt(
  persistedRoles: string[],
  accessToken: string | null,
): string[] {
  return [
    ...new Set([...persistedRoles, ...parseRolesFromJwt(accessToken)]),
  ];
}
