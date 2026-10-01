"use client";

import { useTranslations } from "next-intl";
import { UserRound } from "lucide-react";
import { features } from "@/config/features";
import { useRouter } from "next/navigation";
import { useEffect } from "react";

export default function UserPanelPage() {
  const t = useTranslations("UserPanel");
  const router = useRouter();

  useEffect(() => {
    if (!features.userPanel) router.replace("/dashboard");
  }, [router]);

  if (!features.userPanel) return null;

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <UserRound className="size-5 opacity-80" />
        <h1 className="text-2xl font-bold tracking-tight">{t("title")}</h1>
      </div>
      <p className="text-muted-foreground max-w-2xl text-sm">{t("subtitle")}</p>
    </div>
  );
}
