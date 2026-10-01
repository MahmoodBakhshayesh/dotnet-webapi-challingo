"use client";

import { useTranslations } from "next-intl";
import { useMemo, useState } from "react";
import type { LucideIcon } from "lucide-react";
import {
  LayoutDashboard,
  Building2,
  LogOut,
  Menu,
  Users,
  UserRound,
  Shield,
  ClipboardList,
  ShieldCheck,
  SpellCheck,
  Grid3x3,
  CalendarClock,
  Eye,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";
import { Separator } from "@/components/ui/separator";
import { useLogoutController } from "@/features/auth/controllers/logout.controller";
import { useAuthStore } from "@/stores/auth-store";
import Link from "next/link";
import { useAppPathname } from "@/lib/use-app-pathname";
import { LocaleSwitcher } from "@/components/locale-switcher";
import { useIsAdmin } from "@/lib/use-is-admin";
import { features, organizationsEnabled } from "@/config/features";

export type NavBlock =
  | { type: "link"; href: string; label: string; icon: LucideIcon }
  | { type: "label"; label: string };

function NavLinks({
  items,
  onNavigate,
  className,
}: {
  items: NavBlock[];
  onNavigate?: () => void;
  className?: string;
}) {
  const pathname = useAppPathname();
  return (
    <nav className={cn("flex flex-col gap-1", className)}>
      {items.map((item, idx) => {
        if (item.type === "label") {
          return (
            <div
              key={`nav-label-${idx}-${item.label}`}
              className="px-3 pt-3 pb-0.5 text-[11px] font-semibold uppercase tracking-wide text-muted-foreground"
            >
              {item.label}
            </div>
          );
        }
        const { href, label, icon: Icon } = item;
        const active = pathname === href || pathname.startsWith(`${href}/`);
        return (
          <Link
            key={href}
            href={href}
            onClick={onNavigate}
            className={cn(
              "flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
              active
                ? "bg-sidebar-accent text-sidebar-accent-foreground"
                : "text-muted-foreground hover:bg-muted hover:text-foreground",
            )}
          >
            <Icon className="size-4 shrink-0" />
            {label}
          </Link>
        );
      })}
    </nav>
  );
}

export function MainShell({ children }: { children: React.ReactNode }) {
  const [mobileOpen, setMobileOpen] = useState(false);
  const { logout } = useLogoutController();
  const username = useAuthStore((s) => s.username);
  const t = useTranslations("Nav");
  const tc = useTranslations("Common");
  const isAdmin = useIsAdmin();

  const homeHref = "/dashboard";

  const navItems = useMemo((): NavBlock[] => {
    const blocks: NavBlock[] = [
      { type: "link", href: "/dashboard", label: t("dashboard"), icon: LayoutDashboard },
    ];

    if (features.operatorPanel) {
      blocks.push({
        type: "link",
        href: "/ops",
        label: t("operatorPanel"),
        icon: ClipboardList,
      });
    }

    if (features.userPanel) {
      blocks.push({
        type: "link",
        href: "/account",
        label: t("userPanel"),
        icon: UserRound,
      });
    }

    if (features.adminPanel && isAdmin) {
      blocks.push({ type: "label", label: t("adminSection") });
      blocks.push({
        type: "link",
        href: "/admin",
        label: t("adminConsole"),
        icon: Shield,
      });
      blocks.push({
        type: "link",
        href: "/admin/users",
        label: t("users"),
        icon: Users,
      });
      blocks.push({
        type: "link",
        href: "/admin/roles",
        label: t("roles"),
        icon: ShieldCheck,
      });
      blocks.push({ type: "label", label: t("puzzlesSection") });
      blocks.push({
        type: "link",
        href: "/admin/content/word-guess",
        label: t("wordGuessAnswers"),
        icon: SpellCheck,
      });
      blocks.push({
        type: "link",
        href: "/admin/content/crosswords",
        label: t("crosswords"),
        icon: Grid3x3,
      });
      blocks.push({
        type: "link",
        href: "/admin/schedule",
        label: t("schedule"),
        icon: CalendarClock,
      });
      blocks.push({
        type: "link",
        href: "/admin/puzzles",
        label: t("puzzlePreview"),
        icon: Eye,
      });
      if (organizationsEnabled()) {
        blocks.push({
          type: "link",
          href: "/organizations",
          label: t("organizations"),
          icon: Building2,
        });
      }
    }

    blocks.push({ type: "link", href: "/profile", label: t("profile"), icon: UserRound });
    return blocks;
  }, [t, isAdmin]);

  return (
    <div className="flex min-h-screen flex-col bg-background md:flex-row">
      <aside className="hidden w-64 shrink-0 border-e bg-sidebar text-sidebar-foreground md:flex md:flex-col">
        <div className="flex h-14 items-center border-b border-sidebar-border px-4">
          <Link href={homeHref} className="font-semibold tracking-tight">
            {t("brand")}
          </Link>
        </div>
        <div className="flex flex-1 flex-col gap-2 p-3">
          <LocaleSwitcher />
          <NavLinks items={navItems} />
          <Separator className="my-2 bg-sidebar-border" />
          <p className="truncate px-3 text-xs text-muted-foreground">
            {username ?? tc("userFallback")}
          </p>
          <Button
            variant="outline"
            size="sm"
            className="justify-start gap-2"
            onClick={() => void logout()}
          >
            <LogOut className="size-4" />
            {t("logout")}
          </Button>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-40 flex h-14 items-center gap-2 border-b bg-background/95 px-4 backdrop-blur md:hidden">
          <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
            <SheetTrigger
              render={
                <Button variant="outline" size="icon" aria-label={t("openMenu")}>
                  <Menu className="size-4" />
                </Button>
              }
            />
            <SheetContent side="left" className="w-72">
              <SheetHeader>
                <SheetTitle>{t("brand")}</SheetTitle>
              </SheetHeader>
              <div className="mt-6 flex flex-col gap-4">
                <LocaleSwitcher />
                <NavLinks
                  items={navItems}
                  onNavigate={() => setMobileOpen(false)}
                />
                <Separator />
                <Button
                  variant="outline"
                  onClick={() => {
                    setMobileOpen(false);
                    void logout();
                  }}
                >
                  <LogOut className="me-2 size-4" />
                  {t("logout")}
                </Button>
              </div>
            </SheetContent>
          </Sheet>
          <span className="font-medium">{t("brand")}</span>
          <div className="ms-auto w-[140px] shrink-0">
            <LocaleSwitcher />
          </div>
        </header>

        <main className="mx-auto w-full max-w-6xl flex-1 p-4 md:p-8">{children}</main>
      </div>
    </div>
  );
}
