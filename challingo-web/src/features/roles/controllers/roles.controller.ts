"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";
import {
  emptyPermissions,
  type RoleDto,
  type RolePermissionDto,
} from "@/features/roles/repositories/roles.repository";
import { createRoleUseCase } from "@/features/roles/usecases/create-role.usecase";
import { deleteRoleUseCase } from "@/features/roles/usecases/delete-role.usecase";
import { listRolesUseCase } from "@/features/roles/usecases/list-roles.usecase";
import { updateRoleUseCase } from "@/features/roles/usecases/update-role.usecase";
import { queryKeys } from "@/lib/query-keys";
import { toastError } from "@/lib/toast-error";

function clonePermissions(source?: RolePermissionDto[]): RolePermissionDto[] {
  const base = emptyPermissions();
  if (!source?.length) return base;
  return base.map((row) => {
    const match = source.find(
      (s) => s.resource.toLowerCase() === row.resource.toLowerCase(),
    );
    return match
      ? {
          resource: row.resource,
          create: !!match.create,
          read: !!match.read,
          update: !!match.update,
          delete: !!match.delete,
        }
      : row;
  });
}

/** Orchestrates roles list: owns dialog/form state and calls use cases (never repos). */
export function useRolesController() {
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<RoleDto | null>(null);
  const [name, setName] = useState("");
  const [permissions, setPermissions] = useState<RolePermissionDto[]>(
    emptyPermissions(),
  );

  const rolesQuery = useQuery({
    queryKey: queryKeys.roles,
    queryFn: listRolesUseCase,
  });

  const saveMutation = useMutation({
    mutationFn: async () => {
      if (!name.trim()) throw new Error("Role name is required");
      if (editing) {
        return updateRoleUseCase({
          id: editing.id,
          body: {
            name: editing.isSystem ? undefined : name.trim(),
            permissions,
          },
        });
      }
      return createRoleUseCase({
        name: name.trim(),
        permissions,
      });
    },
    onSuccess: async () => {
      toast.success(editing ? "Role updated" : "Role created");
      setOpen(false);
      setEditing(null);
      await qc.invalidateQueries({ queryKey: queryKeys.roles });
    },
    onError: (e: Error) => toastError(e, "Request failed"),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteRoleUseCase,
    onSuccess: async () => {
      toast.success("Role deleted");
      await qc.invalidateQueries({ queryKey: queryKeys.roles });
    },
    onError: (e: Error) => toastError(e, "Request failed"),
  });

  return {
    viewState: {
      roles: rolesQuery.data ?? [],
      isLoading: rolesQuery.isLoading,
      isError: rolesQuery.isError,
      errorMessage: rolesQuery.isError
        ? (rolesQuery.error as Error).message
        : null,
      open,
      editing,
      name,
      permissions,
    },
    actions: {
      setOpen,
      setName,
      openCreate: () => {
        setEditing(null);
        setName("");
        setPermissions(emptyPermissions());
        setOpen(true);
      },
      openEdit: (role: RoleDto) => {
        setEditing(role);
        setName(role.name);
        setPermissions(clonePermissions(role.permissions));
        setOpen(true);
      },
      togglePermission: (
        resource: string,
        key: keyof Omit<RolePermissionDto, "resource">,
      ) => {
        setPermissions((rows) =>
          rows.map((row) =>
            row.resource === resource ? { ...row, [key]: !row[key] } : row,
          ),
        );
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

export type RolesViewModel = ReturnType<typeof useRolesController>;
