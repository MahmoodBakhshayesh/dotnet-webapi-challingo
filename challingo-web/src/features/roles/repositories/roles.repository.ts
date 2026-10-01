/**
 * Data source: API role endpoints.
 * No business rules — transport only.
 */
import { apiJson } from "@/lib/api-client";

export type RolePermissionDto = {
  resource: string;
  create: boolean;
  read: boolean;
  update: boolean;
  delete: boolean;
};

export type RoleDto = {
  id: string;
  name: string;
  isSystem: boolean;
  permissions: RolePermissionDto[];
};

export const PERMISSION_RESOURCES = ["Users", "Organizations", "Roles"] as const;

export function emptyPermissions(): RolePermissionDto[] {
  return PERMISSION_RESOURCES.map((resource) => ({
    resource,
    create: false,
    read: false,
    update: false,
    delete: false,
  }));
}

export const rolesRepository = {
  list() {
    return apiJson<RoleDto[]>("/api/roles");
  },
  create(body: { name: string; permissions: RolePermissionDto[] }) {
    return apiJson<RoleDto>("/api/roles", {
      method: "POST",
      body: JSON.stringify(body),
    });
  },
  update(
    id: string,
    body: { name?: string; permissions: RolePermissionDto[] },
  ) {
    return apiJson<RoleDto>(`/api/roles/${id}`, {
      method: "PUT",
      body: JSON.stringify(body),
    });
  },
  remove(id: string) {
    return apiJson<unknown>(`/api/roles/${id}`, { method: "DELETE" });
  },
};
