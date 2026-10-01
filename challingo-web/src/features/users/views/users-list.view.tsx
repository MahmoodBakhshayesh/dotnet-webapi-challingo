/** Presentational: reads only `viewState` + invokes `actions`. No repos / use cases. */
"use client";

import { Pencil, Plus, Trash2, Users } from "lucide-react";
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
import type { UsersViewModel } from "@/features/users/controllers/users.controller";

export function UsersListView({ viewState, actions, pending }: UsersViewModel) {
  const rows = viewState.users;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <Users className="size-5 opacity-80" />
          <div>
            <h1 className="text-2xl font-bold tracking-tight">Users</h1>
            <p className="text-muted-foreground text-sm">
              Create, edit, and remove accounts. Assign roles by name.
            </p>
          </div>
        </div>
        <Button onClick={actions.openCreate}>
          <Plus className="size-4" />
          Add user
        </Button>
      </div>

      {viewState.isLoading ? (
        <p className="text-muted-foreground text-sm">Loading users…</p>
      ) : viewState.isError ? (
        <p className="text-destructive text-sm">{viewState.errorMessage}</p>
      ) : rows.length === 0 ? (
        <p className="text-muted-foreground text-sm">No users yet.</p>
      ) : (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full min-w-[640px] text-left text-sm">
            <thead className="bg-muted/50 border-b">
              <tr>
                <th className="px-3 py-2 font-medium">Username</th>
                <th className="px-3 py-2 font-medium">Email</th>
                <th className="px-3 py-2 font-medium">Phone</th>
                <th className="px-3 py-2 font-medium">Roles</th>
                <th className="px-3 py-2 font-medium text-end">Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((u) => (
                <tr key={u.id} className="border-b last:border-0">
                  <td className="px-3 py-2 font-medium">{u.userName}</td>
                  <td className="px-3 py-2">{u.email || "—"}</td>
                  <td className="px-3 py-2">{u.phoneNumber || "—"}</td>
                  <td className="px-3 py-2">
                    {(u.roles ?? []).join(", ") || "—"}
                  </td>
                  <td className="px-3 py-2">
                    <div className="flex justify-end gap-1">
                      <Button
                        variant="ghost"
                        size="icon-sm"
                        onClick={() => actions.openEdit(u)}
                        aria-label="Edit"
                      >
                        <Pencil className="size-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon-sm"
                        onClick={() => {
                          if (confirm(`Delete user "${u.userName}"?`)) {
                            actions.remove(u.id);
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
              {viewState.editing ? "Edit user" : "Add user"}
            </DialogTitle>
          </DialogHeader>
          <div className="grid gap-3">
            {!viewState.editing ? (
              <div className="grid gap-1.5">
                <Label htmlFor="userName">Username</Label>
                <Input
                  id="userName"
                  value={viewState.form.userName}
                  onChange={(e) =>
                    actions.setForm((f) => ({ ...f, userName: e.target.value }))
                  }
                />
              </div>
            ) : null}
            <div className="grid gap-1.5">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                value={viewState.form.email}
                onChange={(e) =>
                  actions.setForm((f) => ({ ...f, email: e.target.value }))
                }
              />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="phone">Phone</Label>
              <Input
                id="phone"
                value={viewState.form.phoneNumber}
                onChange={(e) =>
                  actions.setForm((f) => ({
                    ...f,
                    phoneNumber: e.target.value,
                  }))
                }
              />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="roles">Roles (comma-separated)</Label>
              <Input
                id="roles"
                value={viewState.form.rolesCsv}
                onChange={(e) =>
                  actions.setForm((f) => ({ ...f, rolesCsv: e.target.value }))
                }
                placeholder={viewState.roleOptions.join(", ") || "Member"}
              />
              {viewState.roleOptions.length > 0 ? (
                <p className="text-muted-foreground text-xs">
                  Available: {viewState.roleOptions.join(", ")}
                </p>
              ) : null}
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="password">
                {viewState.editing ? "New password (optional)" : "Password"}
              </Label>
              <Input
                id="password"
                type="password"
                value={viewState.form.password}
                onChange={(e) =>
                  actions.setForm((f) => ({ ...f, password: e.target.value }))
                }
              />
            </div>
            {!viewState.editing || viewState.form.password ? (
              <div className="grid gap-1.5">
                <Label htmlFor="passwordConfirm">Confirm password</Label>
                <Input
                  id="passwordConfirm"
                  type="password"
                  value={viewState.form.passwordConfirm}
                  onChange={(e) =>
                    actions.setForm((f) => ({
                      ...f,
                      passwordConfirm: e.target.value,
                    }))
                  }
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
