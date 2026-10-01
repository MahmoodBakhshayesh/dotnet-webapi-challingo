"use client";

import { useTranslations } from "next-intl";
import { Shield } from "lucide-react";
import Link from "next/link";
import { buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { organizationsEnabled } from "@/config/features";

export default function AdminHomePage() {
  const t = useTranslations("Admin");

  return (
    <div className="space-y-6">
      <div className="flex items-start gap-3">
        <Shield className="mt-1 size-6 opacity-80" />
        <div>
          <h1 className="text-3xl font-bold tracking-tight">{t("title")}</h1>
          <p className="text-muted-foreground mt-2 max-w-2xl text-sm">
            Manage users, roles (with CRUD permissions), and organizations.
          </p>
        </div>
      </div>
      <div className="flex flex-wrap gap-3">
        <Link href="/admin/users" className={cn(buttonVariants())}>
          {t("manageUsers")}
        </Link>
        <Link href="/admin/roles" className={cn(buttonVariants({ variant: "outline" }))}>
          {t("manageRoles")}
        </Link>
        {organizationsEnabled() ? (
          <Link
            href="/organizations"
            className={cn(buttonVariants({ variant: "outline" }))}
          >
            {t("manageOrgs")}
          </Link>
        ) : null}
      </div>
    </div>
  );
}
