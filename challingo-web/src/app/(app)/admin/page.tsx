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
            Manage users and roles, review puzzle content (Word Guess answers, crosswords), and preview any game.
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
        <Link href="/admin/content/word-guess" className={cn(buttonVariants({ variant: "outline" }))}>
          Word Guess answers
        </Link>
        <Link href="/admin/content/crosswords" className={cn(buttonVariants({ variant: "outline" }))}>
          Crosswords
        </Link>
        <Link href="/admin/schedule" className={cn(buttonVariants({ variant: "outline" }))}>
          Schedule
        </Link>
        <Link href="/admin/puzzles" className={cn(buttonVariants({ variant: "outline" }))}>
          Puzzle preview
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
