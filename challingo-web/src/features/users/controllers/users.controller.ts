"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { toast } from "sonner";
import { createUserUseCase } from "@/features/users/usecases/create-user.usecase";
import { deleteUserUseCase } from "@/features/users/usecases/delete-user.usecase";
import { listUsersUseCase } from "@/features/users/usecases/list-users.usecase";
import { updateUserUseCase } from "@/features/users/usecases/update-user.usecase";
import type { UserDto } from "@/features/users/repositories/users.repository";
import { listRolesUseCase } from "@/features/roles/usecases/list-roles.usecase";
import { queryKeys } from "@/lib/query-keys";
import { toastError } from "@/lib/toast-error";

export type UserForm = {
  userName: string;
  email: string;
  phoneNumber: string;
  password: string;
  passwordConfirm: string;
  rolesCsv: string;
};

const emptyForm = (): UserForm => ({
  userName: "",
  email: "",
  phoneNumber: "",
  password: "",
  passwordConfirm: "",
  rolesCsv: "Member",
});

/** Orchestrates users list: owns dialog/form state and calls use cases (never repos). */
export function useUsersController() {
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<UserDto | null>(null);
  const [form, setForm] = useState<UserForm>(emptyForm());

  const usersQuery = useQuery({
    queryKey: queryKeys.users,
    queryFn: listUsersUseCase,
  });

  const rolesQuery = useQuery({
    queryKey: queryKeys.roles,
    queryFn: listRolesUseCase,
  });

  const roleOptions = useMemo(
    () => (rolesQuery.data ?? []).map((r) => r.name),
    [rolesQuery.data],
  );

  const saveMutation = useMutation({
    mutationFn: async () => {
      const roles = form.rolesCsv
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
      if (editing) {
        return updateUserUseCase({
          id: editing.id,
          body: {
            email: form.email || undefined,
            phoneNumber: form.phoneNumber || undefined,
            password: form.password || undefined,
            roles,
          },
        });
      }
      if (!form.password) throw new Error("Password is required");
      if (form.password !== form.passwordConfirm) {
        throw new Error("Password confirmation does not match");
      }
      return createUserUseCase({
        userName: form.userName,
        email: form.email || undefined,
        phoneNumber: form.phoneNumber || undefined,
        password: form.password,
        passwordConfirm: form.passwordConfirm,
        roles,
      });
    },
    onSuccess: async () => {
      toast.success(editing ? "User updated" : "User created");
      setOpen(false);
      setEditing(null);
      setForm(emptyForm());
      await qc.invalidateQueries({ queryKey: queryKeys.users });
    },
    onError: (e: Error) => toastError(e, "Request failed"),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteUserUseCase,
    onSuccess: async () => {
      toast.success("User deleted");
      await qc.invalidateQueries({ queryKey: queryKeys.users });
    },
    onError: (e: Error) => toastError(e, "Request failed"),
  });

  return {
    viewState: {
      users: usersQuery.data ?? [],
      isLoading: usersQuery.isLoading,
      isError: usersQuery.isError,
      errorMessage: usersQuery.isError
        ? (usersQuery.error as Error).message
        : null,
      open,
      editing,
      form,
      roleOptions,
    },
    actions: {
      setOpen,
      setForm,
      openCreate: () => {
        setEditing(null);
        setForm(emptyForm());
        setOpen(true);
      },
      openEdit: (user: UserDto) => {
        setEditing(user);
        setForm({
          userName: user.userName,
          email: user.email ?? "",
          phoneNumber: user.phoneNumber ?? "",
          password: "",
          passwordConfirm: "",
          rolesCsv: (user.roles ?? []).join(", "),
        });
        setOpen(true);
      },
      save: () => saveMutation.mutate(),
      remove: (id: string) => deleteMutation.mutate(id),
    },
    pending: {
      save: saveMutation.isPending,
      delete: deleteMutation.isPending,
    },
  };
}

export type UsersViewModel = ReturnType<typeof useUsersController>;
