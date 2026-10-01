"use client";

import { usePathname } from "next/navigation";

/** App pathname for nav active state and route guards. */
export function useAppPathname(): string {
  return usePathname() || "/";
}
