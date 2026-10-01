"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { organizationsEnabled } from "@/config/features";
import { useOrganizationsController } from "@/features/organizations/controllers/organizations.controller";
import { OrganizationsListView } from "@/features/organizations/views/organizations-list.view";

export default function OrganizationsPage() {
  const router = useRouter();
  const enabled = organizationsEnabled();

  useEffect(() => {
    if (!enabled) router.replace("/dashboard");
  }, [router, enabled]);

  const vm = useOrganizationsController({ enabled });

  if (!enabled) return null;

  return <OrganizationsListView {...vm} />;
}
