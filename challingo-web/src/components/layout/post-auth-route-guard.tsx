"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo } from "react";
import { features, organizationsEnabled } from "@/config/features";
import { mergeRolesFromJwt } from "@/lib/jwt-roles";
import { isAdminRole } from "@/lib/roles";
import { useAppPathname } from "@/lib/use-app-pathname";
import { useAuthStore } from "@/stores/auth-store";

/**
 * Enforces panel feature flags and admin-only routes after login.
 */
export function PostAuthRouteGuard({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const pathname = useAppPathname();
  const accessToken = useAuthStore((s) => s.accessToken);
  const persistedRoles = useAuthStore((s) => s.roles);
  const roles = useMemo(
    () => mergeRolesFromJwt(persistedRoles, accessToken),
    [persistedRoles, accessToken],
  );
  const isAdmin = isAdminRole(roles);

  useEffect(() => {
    if (!accessToken) return;

    const isAdminPath =
      pathname === "/admin" ||
      pathname.startsWith("/admin/") ||
      pathname === "/users" ||
      pathname.startsWith("/users/");

    if (isAdminPath && !isAdmin) {
      router.replace("/dashboard");
      return;
    }

    if (
      !features.operatorPanel &&
      (pathname === "/ops" || pathname.startsWith("/ops/"))
    ) {
      router.replace("/dashboard");
      return;
    }

    if (
      !features.userPanel &&
      (pathname === "/account" || pathname.startsWith("/account/"))
    ) {
      router.replace("/dashboard");
      return;
    }

    if (
      !organizationsEnabled() &&
      (pathname === "/organizations" || pathname.startsWith("/organizations/"))
    ) {
      router.replace("/dashboard");
    }
  }, [accessToken, pathname, isAdmin, router]);

  return <>{children}</>;
}
