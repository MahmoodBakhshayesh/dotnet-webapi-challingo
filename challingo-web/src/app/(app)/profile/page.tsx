"use client";

import { useTranslations } from "next-intl";
import { UserRound } from "lucide-react";
import { useAuthStore } from "@/stores/auth-store";

export default function ProfilePage() {
  const t = useTranslations("Nav");
  const username = useAuthStore((s) => s.username);

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <UserRound className="size-5 opacity-80" />
        <h1 className="text-2xl font-bold tracking-tight">{t("profile")}</h1>
      </div>
      <p className="text-muted-foreground text-sm">{username ?? "—"}</p>
    </div>
  );
}
