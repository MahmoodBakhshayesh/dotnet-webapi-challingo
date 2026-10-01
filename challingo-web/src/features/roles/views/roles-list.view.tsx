/** Presentational: reads only `viewState` + invokes `actions`. No repos / use cases. */
"use client";

import { Pencil, Plus, ShieldCheck, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import type { RolesViewModel } from "@/features/roles/controllers/roles.controller";
import type { RoleDto } from "@/features/roles/repositories/roles.repository";
import { cn } from "@/lib/utils";

function formatPerms(role: RoleDto): string {
  const parts: string[] = [];
  for (const p of role.permissions ?? []) {
    const flags = [
      p.create ? "C" : "",
      p.read ? "R" : "",
      p.update ? "U" : "",
      p.delete ? "D" : "",
    ].join("");
    if (flags) parts.push(`${p.resource}:${flags}`);
  }
  return parts.join(" · ") || "—";
}

export function RolesListView({ viewState, actions, pending }: RolesViewModel) {
  const rows = viewState.roles;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <ShieldCheck className="size-5 opacity-80" />
          <div>
            <h1 className="text-2xl font-bold tracking-tight">Roles</h1>
            <p className="text-muted-foreground text-sm">
              Manage roles and set Create / Read / Update / Delete per resource.
            </p>
          </div>
        </div>
        <Button onClick={actions.openCreate}>
          <Plus className="size-4" />
          Add role
        </Button>
      </div>

      {viewState.isLoading ? (
        <p className="text-muted-foreground text-sm">Loading roles…</p>
      ) : viewState.isError ? (
        <p className="text-destructive text-sm">{viewState.errorMessage}</p>
      ) : rows.length === 0 ? (
        <p className="text-muted-foreground text-sm">No roles yet.</p>
      ) : (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full min-w-[640px] text-left text-sm">
            <thead className="bg-muted/50 border-b">
              <tr>
                <th className="px-3 py-2 font-medium">Name</th>
                <th className="px-3 py-2 font-medium">Type</th>
                <th className="px-3 py-2 font-medium">Permissions</th>
                <th className="px-3 py-2 font-medium text-end">Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((role) => (
                <tr key={role.id} className="border-b last:border-0">
                  <td className="px-3 py-2 font-medium">{role.name}</td>
                  <td className="px-3 py-2">
                    {role.isSystem ? "System" : "Custom"}
                  </td>
                  <td className="text-muted-foreground px-3 py-2 text-xs">
                    {formatPerms(role)}
                  </td>
                  <td className="px-3 py-2">
                    <div className="flex justify-end gap-1">
                      <Button
                        variant="ghost"
                        size="icon-sm"
                        onClick={() => actions.openEdit(role)}
                        aria-label="Edit"
                      >
                        <Pencil className="size-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon-sm"
                        disabled={role.isSystem}
                        onClick={() => {
                          if (confirm(`Delete role "${role.name}"?`)) {
                            actions.remove(role.id);
                          }
                        }}
                        aria-label="Delete"
                      >
                        <Trash2 className="size-4" />
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <Dialog open={viewState.open} onOpenChange={actions.setOpen}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>
              {viewState.editing ? "Edit role" : "Add role"}
            </DialogTitle>
          </DialogHeader>
          <div className="grid gap-4">
            <div className="grid gap-1.5">
              <Label htmlFor="roleName">Name</Label>
              <Input
                id="roleName"
                value={viewState.name}
                disabled={!!viewState.editing?.isSystem}
                onChange={(e) => actions.setName(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label>CRUD permissions</Label>
              <div className="overflow-x-auto rounded-md border">
                <table className="w-full text-sm">
                  <thead className="bg-muted/40">
                    <tr>
                      <th className="px-2 py-1.5 text-start font-medium">
                        Resource
                      </th>
                      {(["create", "read", "update", "delete"] as const).map(
                        (k) => (
                          <th
                            key={k}
                            className="px-2 py-1.5 text-center font-medium capitalize"
                          >
                            {k}
                          </th>
                        ),
                      )}
                    </tr>
                  </thead>
                  <tbody>
                    {viewState.permissions.map((row) => (
                      <tr key={row.resource} className="border-t">
                        <td className="px-2 py-1.5">{row.resource}</td>
                        {(
                          ["create", "read", "update", "delete"] as const
                        ).map((k) => (
                          <td key={k} className="px-2 py-1.5 text-center">
                            <input
                              type="checkbox"
                              className={cn("size-4 accent-primary")}
                              checked={row[k]}
                              onChange={() =>
                                actions.togglePermission(row.resource, k)
                              }
                              aria-label={`${row.resource} ${k}`}
                            />
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => actions.setOpen(false)}>
              Cancel
            </Button>
            <Button disabled={pending.save} onClick={() => actions.save()}>
              {pending.save ? "Saving…" : "Save"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
