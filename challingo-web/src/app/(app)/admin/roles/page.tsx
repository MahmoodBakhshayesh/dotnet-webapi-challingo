"use client";

import { useRolesController } from "@/features/roles/controllers/roles.controller";
import { RolesListView } from "@/features/roles/views/roles-list.view";

export default function AdminRolesPage() {
  return <RolesListView {...useRolesController()} />;
}
