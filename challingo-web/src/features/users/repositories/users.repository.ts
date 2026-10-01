/**
 * Data source: API user endpoints.
 * No business rules — transport only.
 */
import { apiJson } from "@/lib/api-client";

export type UserDto = {
  id: string;
  userName: string;
  email?: string | null;
  phoneNumber?: string | null;
  roles: string[];
};

export const usersRepository = {
  list() {
    return apiJson<UserDto[]>("/api/users");
  },
  create(body: {
    userName: string;
    password: string;
    passwordConfirm: string;
    email?: string;
    phoneNumber?: string;
    roles?: string[];
  }) {
    return apiJson<UserDto>("/api/users", {
      method: "POST",
      body: JSON.stringify(body),
    });
  },
  update(
    id: string,
    body: {
      email?: string;
      phoneNumber?: string;
      password?: string;
      roles?: string[];
    },
  ) {
    return apiJson<UserDto>(`/api/users/${id}`, {
      method: "PUT",
      body: JSON.stringify(body),
    });
  },
  remove(id: string) {
    return apiJson<unknown>(`/api/users/${id}`, { method: "DELETE" });
  },
};
