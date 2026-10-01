"use client";

import { useUsersController } from "@/features/users/controllers/users.controller";
import { UsersListView } from "@/features/users/views/users-list.view";

export default function AdminUsersPage() {
  return <UsersListView {...useUsersController()} />;
}
