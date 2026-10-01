"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";
import type { OrganizationDto } from "@/features/organizations/repositories/organizations.repository";
import { createOrganizationUseCase } from "@/features/organizations/usecases/create-organization.usecase";
import { deleteOrganizationUseCase } from "@/features/organizations/usecases/delete-organization.usecase";
import { listOrganizationsUseCase } from "@/features/organizations/usecases/list-organizations.usecase";
import { updateOrganizationUseCase } from "@/features/organizations/usecases/update-organization.usecase";
import { queryKeys } from "@/lib/query-keys";
import { toastError } from "@/lib/toast-error";

/** Orchestrates organizations list: owns dialog/form state and calls use cases (never repos). */
export function useOrganizationsController(options?: { enabled?: boolean }) {
  const enabled = options?.enabled ?? true;
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<OrganizationDto | null>(null);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");

  const orgsQuery = useQuery({
    queryKey: queryKeys.organizations,
    enabled,
    queryFn: listOrganizationsUseCase,
  });

  const saveMutation = useMutation({
    mutationFn: async () => {
      if (!name.trim()) throw new Error("Name is required");
      if (editing) {
        return updateOrganizationUseCase({
          id: editing.id,
          body: {
            name: name.trim(),
            description: description.trim() || undefined,
          },
        });
      }
      return createOrganizationUseCase({ name: name.trim() });
    },
    onSuccess: async () => {
      toast.success(editing ? "Organization updated" : "Organization created");
      setOpen(false);
      setEditing(null);
      await qc.invalidateQueries({ queryKey: queryKeys.organizations });
    },
    onError: (e: Error) => toastError(e, "Request failed"),
  });

  const deleteMutation = useMutation({
    mutationFn: deleteOrganizationUseCase,
    onSuccess: async () => {
      toast.success("Organization deleted");
      await qc.invalidateQueries({ queryKey: queryKeys.organizations });
    },
    onError: (e: Error) => toastError(e, "Request failed"),
  });

  return {
    viewState: {
      organizations: orgsQuery.data ?? [],
      isLoading: orgsQuery.isLoading,
      isError: orgsQuery.isError,
      errorMessage: orgsQuery.isError
        ? (orgsQuery.error as Error).message
        : null,
      open,
      editing,
      name,
      description,
    },
    actions: {
      setOpen,
      setName,
      setDescription,
      openCreate: () => {
        setEditing(null);
        setName("");
        setDescription("");
        setOpen(true);
      },
      openEdit: (org: OrganizationDto) => {
        setEditing(org);
        setName(org.name);
        setDescription(org.description ?? "");
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

export type OrganizationsViewModel = ReturnType<
  typeof useOrganizationsController
>;
