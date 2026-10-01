"use client";

import { useTranslations } from "next-intl";
import {
  Building2,
  Shield,
  Users,
  ArrowRight,
  ClipboardList,
  UserRound,
} from "lucide-react";
import {
  Card,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import Link from "next/link";
import { features, organizationsEnabled } from "@/config/features";
import { useIsAdmin } from "@/lib/use-is-admin";

export default function DashboardPage() {
  const t = useTranslations("Dashboard");
  const isAdmin = useIsAdmin();

  const tiles: {
    titleKey: "adminTitle" | "usersTitle" | "orgsTitle" | "opsTitle" | "accountTitle";
    descKey: "adminDesc" | "usersDesc" | "orgsDesc" | "opsDesc" | "accountDesc";
    href: string;
    icon: typeof Shield;
    show: boolean;
  }[] = [
    {
      titleKey: "adminTitle",
      descKey: "adminDesc",
      href: "/admin",
      icon: Shield,
      show: features.adminPanel && isAdmin,
    },
    {
      titleKey: "usersTitle",
      descKey: "usersDesc",
      href: "/admin/users",
      icon: Users,
      show: features.adminPanel && isAdmin,
    },
    {
      titleKey: "orgsTitle",
      descKey: "orgsDesc",
      href: "/organizations",
      icon: Building2,
      show: features.adminPanel && isAdmin && organizationsEnabled(),
    },
    {
      titleKey: "opsTitle",
      descKey: "opsDesc",
      href: "/ops",
      icon: ClipboardList,
      show: features.operatorPanel,
    },
    {
      titleKey: "accountTitle",
      descKey: "accountDesc",
      href: "/account",
      icon: UserRound,
      show: features.userPanel,
    },
  ];

  const visible = tiles.filter((x) => x.show);

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">{t("title")}</h1>
        <p className="text-muted-foreground mt-2 max-w-2xl text-sm md:text-base">
          {t("subtitle")}
        </p>
      </div>

      {visible.length === 0 ? (
        <p className="text-muted-foreground text-sm">{t("emptyHint")}</p>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {visible.map(({ titleKey, descKey, href, icon: Icon }) => (
            <Card key={href} className="transition-shadow hover:shadow-md">
              <CardHeader className="flex flex-row items-start justify-between gap-4 space-y-0">
                <div className="space-y-1">
                  <CardTitle className="flex items-center gap-2 text-lg">
                    <Icon className="size-5 opacity-80" />
                    {t(titleKey)}
                  </CardTitle>
                  <CardDescription>{t(descKey)}</CardDescription>
                </div>
                <Link
                  href={href}
                  aria-label={t(titleKey)}
                  className={cn(
                    buttonVariants({ variant: "ghost", size: "icon" }),
                  )}
                >
                  <ArrowRight className="size-4 rtl:rotate-180" />
                </Link>
              </CardHeader>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
