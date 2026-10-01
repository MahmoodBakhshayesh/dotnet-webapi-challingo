"use client";

import { NextIntlClientProvider } from "next-intl";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import enMessages from "../../messages/en.json";
import faMessages from "../../messages/fa.json";
import {
  availableLocales,
  features,
  isRtlLocale,
  type UiLocale,
} from "@/config/features";

export type { UiLocale };

const STORAGE_KEY = "web-app-ui-locale";

const messagesByLocale = {
  en: enMessages,
  fa: faMessages,
} as const;

type LocaleContextValue = {
  locale: UiLocale;
  setLocale: (locale: UiLocale) => void;
  locales: readonly UiLocale[];
};

const LocaleContext = createContext<LocaleContextValue | null>(null);

export function useUiLocale(): LocaleContextValue {
  const ctx = useContext(LocaleContext);
  if (!ctx) {
    throw new Error("useUiLocale must be used within LocaleUiProvider");
  }
  return ctx;
}

function resolveInitialLocale(): UiLocale {
  const allowed = availableLocales();
  const fallback = features.defaultLocale;
  if (!features.multiLanguage) return fallback;
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored === "fa" || stored === "en") {
      if (allowed.includes(stored)) return stored;
    }
  } catch {
    /* ignore */
  }
  return fallback;
}

function applyDocumentLocale(locale: UiLocale) {
  document.documentElement.lang = locale;
  document.documentElement.dir = isRtlLocale(locale) ? "rtl" : "ltr";
  if (isRtlLocale(locale)) {
    document.body.style.fontFamily =
      "var(--font-vazirmatn), var(--font-roboto), ui-sans-serif, system-ui, sans-serif";
  } else {
    document.body.style.fontFamily =
      "var(--font-roboto), ui-sans-serif, system-ui, sans-serif";
  }
}

export function LocaleUiProvider({ children }: { children: ReactNode }) {
  const locales = availableLocales();
  const [locale, setLocaleState] = useState<UiLocale>(features.defaultLocale);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const initial = resolveInitialLocale();
    setLocaleState(initial);
    applyDocumentLocale(initial);
    setReady(true);
  }, []);

  const setLocale = useCallback(
    (next: UiLocale) => {
      if (!locales.includes(next)) return;
      setLocaleState(next);
      if (features.multiLanguage) {
        try {
          localStorage.setItem(STORAGE_KEY, next);
        } catch {
          /* ignore */
        }
      }
    },
    [locales],
  );

  useEffect(() => {
    if (!ready) return;
    applyDocumentLocale(locale);
  }, [locale, ready]);

  const messages = useMemo(() => messagesByLocale[locale], [locale]);

  return (
    <LocaleContext.Provider value={{ locale, setLocale, locales }}>
      <NextIntlClientProvider
        locale={locale}
        messages={messages}
        timeZone="UTC"
      >
        {children}
      </NextIntlClientProvider>
    </LocaleContext.Provider>
  );
}
