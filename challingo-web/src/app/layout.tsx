import "./globals.css";
import type { Metadata } from "next";
import { MaintenanceGate } from "@/components/maintenance-gate";
import { AppProviders } from "@/providers/app-providers";
import { LocaleUiProvider } from "@/providers/locale-ui-provider";
import { features, isRtlLocale } from "@/config/features";

export const metadata: Metadata = {
  title: "Challingo",
  description: "Web console for your API",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const locale = features.defaultLocale;
  const dir = isRtlLocale(locale) ? "rtl" : "ltr";

  return (
    <html
      lang={locale}
      dir={dir}
      suppressHydrationWarning
      className="h-full antialiased"
    >
      <body className="flex min-h-full flex-col">
        <LocaleUiProvider>
          <AppProviders>
            <MaintenanceGate>{children}</MaintenanceGate>
          </AppProviders>
        </LocaleUiProvider>
      </body>
    </html>
  );
}
