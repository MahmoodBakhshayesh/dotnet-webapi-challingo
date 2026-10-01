"use client";

import { useEffect, useState } from "react";
import { useAuthStore } from "@/stores/auth-store";

/** True after zustand persist has restored auth from localStorage (SSR-safe). */
export function useAuthStoreHydrated(): boolean {
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    const persist = useAuthStore.persist;
    if (!persist) {
      setHydrated(true);
      return;
    }
    if (persist.hasHydrated()) {
      setHydrated(true);
      return;
    }
    return persist.onFinishHydration(() => {
      setHydrated(true);
    });
  }, []);

  return hydrated;
}
