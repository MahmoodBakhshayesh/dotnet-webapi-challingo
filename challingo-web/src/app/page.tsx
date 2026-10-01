"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { features } from "@/config/features";
import { mergeRolesFromJwt } from "@/lib/jwt-roles";
import { getPostLoginRoute } from "@/lib/roles";
import { useAuthStore } from "@/stores/auth-store";
import { useAuthStoreHydrated } from "@/hooks/use-auth-store-hydrated";
import { LocaleSwitcher } from "@/components/locale-switcher";
import { LandingPage } from "@/components/home/landing-page";
import Link from "next/link";
import { buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";

export default function HomePage() {
  const router = useRouter();
  const token = useAuthStore((s) => s.accessToken);
  const persistedRoles = useAuthStore((s) => s.roles);
  const storeHydrated = useAuthStoreHydrated();
  const t = useTranslations("Common");
  const th = useTranslations("Landing");

  useEffect(() => {
    if (!storeHydrated) return;
    if (features.homeLanding) {
      if (token) {
        const roles = mergeRolesFromJwt(persistedRoles, token);
        router.replace(getPostLoginRoute(roles));
      }
      return;
    }
    if (!token) {
      if (features.loginPage) {
        router.replace("/login");
      }
      return;
    }
    const roles = mergeRolesFromJwt(persistedRoles, token);
    router.replace(getPostLoginRoute(roles));
  }, [storeHydrated, token, persistedRoles, router]);

  if (features.homeLanding && storeHydrated && !token) {
    return <LandingPage />;
  }

  if (!features.homeLanding && !features.loginPage && storeHydrated && !token) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-4 px-4 text-center">
        <LocaleSwitcher />
        <h1 className="text-2xl font-semibold tracking-tight">{th("authDisabledTitle")}</h1>
        <p className="text-muted-foreground max-w-md text-sm">{th("authDisabledBody")}</p>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 px-4">
      <LocaleSwitcher />
      <div className="text-muted-foreground text-sm">{t("redirecting")}</div>
      {features.loginPage ? (
        <Link href="/login" className={cn(buttonVariants({ variant: "link" }))}>
          {t("signInLink")}
        </Link>
      ) : null}
    </div>
  );
}
