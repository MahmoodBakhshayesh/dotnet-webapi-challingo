/**
 * Data source: API organization endpoints.
 * No business rules — transport only.
 */
import { apiJson } from "@/lib/api-client";

export type OrganizationDto = {
  id: string;
  name: string;
  description?: string | null;
};

export const organizationsRepository = {
  list() {
    return apiJson<OrganizationDto[]>("/api/organizations");
  },
  create(body: { name: string }) {
    return apiJson<OrganizationDto>("/api/organizations", {
      method: "POST",
      body: JSON.stringify(body),
    });
  },
  update(id: string, body: { name: string; description?: string }) {
    return apiJson<OrganizationDto>(`/api/organizations/${id}`, {
      method: "PUT",
      body: JSON.stringify(body),
    });
  },
  remove(id: string) {
    return apiJson<unknown>(`/api/organizations/${id}`, { method: "DELETE" });
  },
};
