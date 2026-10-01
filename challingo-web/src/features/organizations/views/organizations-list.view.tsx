/** Presentational: reads only `viewState` + invokes `actions`. No repos / use cases. */
"use client";

import { Building2, Pencil, Plus, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import type { OrganizationsViewModel } from "@/features/organizations/controllers/organizations.controller";

export function OrganizationsListView({
  viewState,
  actions,
  pending,
}: OrganizationsViewModel) {
  const rows = viewState.organizations;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <Building2 className="size-5 opacity-80" />
          <div>
            <h1 className="text-2xl font-bold tracking-tight">Organizations</h1>
            <p className="text-muted-foreground text-sm">
              Manage tenant organizations used by operators and supervisors.
            </p>
          </div>
        </div>
        <Button onClick={actions.openCreate}>
          <Plus className="size-4" />
          Add organization
        </Button>
      </div>

      {viewState.isLoading ? (
        <p className="text-muted-foreground text-sm">Loading…</p>
      ) : viewState.isError ? (
        <p className="text-destructive text-sm">{viewState.errorMessage}</p>
      ) : rows.length === 0 ? (
        <p className="text-muted-foreground text-sm">No organizations yet.</p>
      ) : (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full min-w-[520px] text-left text-sm">
            <thead className="bg-muted/50 border-b">
              <tr>
                <th className="px-3 py-2 font-medium">Name</th>
                <th className="px-3 py-2 font-medium">Description</th>
                <th className="px-3 py-2 font-medium text-end">Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((org) => (
                <tr key={org.id} className="border-b last:border-0">
                  <td className="px-3 py-2 font-medium">{org.name}</td>
                  <td className="text-muted-foreground px-3 py-2">
                    {org.description || "—"}
                  </td>
                  <td className="px-3 py-2">
                    <div className="flex justify-end gap-1">
                      <Button
                        variant="ghost"
                        size="icon-sm"
                        onClick={() => actions.openEdit(org)}
                        aria-label="Edit"
                      >
                        <Pencil className="size-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon-sm"
                        onClick={() => {
                          if (confirm(`Delete organization "${org.name}"?`)) {
                            actions.remove(org.id);
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
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>
              {viewState.editing ? "Edit organization" : "Add organization"}
            </DialogTitle>
          </DialogHeader>
          <div className="grid gap-3">
            <div className="grid gap-1.5">
              <Label htmlFor="orgName">Name</Label>
              <Input
                id="orgName"
                value={viewState.name}
                onChange={(e) => actions.setName(e.target.value)}
              />
            </div>
            {viewState.editing ? (
              <div className="grid gap-1.5">
                <Label htmlFor="orgDesc">Description</Label>
                <Textarea
                  id="orgDesc"
                  value={viewState.description}
                  onChange={(e) => actions.setDescription(e.target.value)}
                  rows={3}
                />
              </div>
            ) : null}
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
