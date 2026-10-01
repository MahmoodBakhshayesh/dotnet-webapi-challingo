"use client";

import { useTranslations } from "next-intl";
import { ClipboardList } from "lucide-react";
import {
  features,
  organizationsEnabled,
  organizationsRequired,
  supervisorsEnabled,
  supervisorsRequired,
} from "@/config/features";
import { useRouter } from "next/navigation";
import { useEffect } from "react";
import Link from "next/link";
import { buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";

export default function OperatorPanelPage() {
  const t = useTranslations("Operator");
  const router = useRouter();

  useEffect(() => {
    if (!features.operatorPanel) router.replace("/dashboard");
  }, [router]);

  if (!features.operatorPanel) return null;

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <ClipboardList className="size-5 opacity-80" />
        <h1 className="text-2xl font-bold tracking-tight">{t("title")}</h1>
      </div>
      <p className="text-muted-foreground max-w-2xl text-sm">{t("subtitle")}</p>

      {organizationsEnabled() ? (
        <p className="text-muted-foreground max-w-2xl text-sm">
          {organizationsRequired() ? t("orgsRequired") : t("orgsOptional")}
        </p>
      ) : null}

      {supervisorsEnabled() ? (
        <p className="text-muted-foreground max-w-2xl text-sm">
          {supervisorsRequired() ? t("supervisorsRequired") : t("supervisorsOptional")}
        </p>
      ) : null}

      {organizationsEnabled() ? (
        <Link href="/organizations" className={cn(buttonVariants({ variant: "outline" }))}>
          {t("openOrgs")}
        </Link>
      ) : null}
    </div>
  );
}
