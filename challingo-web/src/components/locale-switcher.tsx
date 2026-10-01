"use client";

import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useTranslations } from "next-intl";
import { useUiLocale } from "@/providers/locale-ui-provider";
import { features } from "@/config/features";

export function LocaleSwitcher({
  className,
}: {
  className?: string;
}) {
  const t = useTranslations("Common");
  const { locale, setLocale, locales } = useUiLocale();

  if (!features.multiLanguage || locales.length < 2) return null;

  return (
    <div className={className}>
      <Select
        value={locale}
        onValueChange={(next) => {
          if (next === "en" || next === "fa") setLocale(next);
        }}
        items={locales.map((loc) => ({
          value: loc,
          label: loc === "fa" ? t("persian") : t("english"),
        }))}
      >
        <SelectTrigger aria-label={t("language")}>
          <SelectValue placeholder={t("language")} />
        </SelectTrigger>
        <SelectContent>
          {locales.map((loc) => (
            <SelectItem key={loc} value={loc}>
              {loc === "fa" ? t("persian") : t("english")}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}
