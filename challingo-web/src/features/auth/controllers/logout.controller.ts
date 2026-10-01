"use client";

import { useTranslations } from "next-intl";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { logoutUseCase } from "@/features/auth/usecases/logout.usecase";
import { useAuthStore } from "@/stores/auth-store";

/** Shell / layout: logout action via use case only (no repository import). */
export function useLogoutController() {
  const router = useRouter();
  const clearSession = useAuthStore((s) => s.clearSession);
  const t = useTranslations("Common");

  async function logout() {
    await logoutUseCase();
    clearSession();
    toast.message(t("signedOut"));
    router.replace("/login");
  }

  return { logout };
}
