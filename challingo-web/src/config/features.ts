/**
 * Generation-time web surface flags.
 * Rewritten by New-Project / GUI when creating a project.
 * Admin panel is always enabled.
 *
 * organizations / supervisors: "off" | "optional" | "required"
 * defaultLocale: sole language when multiLanguage is false; initial language when true.
 */
export const features = {
  homeLanding: false,
  loginPage: true,
  adminPanel: true,
  operatorPanel: false,
  userPanel: false,
  multiLanguage: false,
  defaultLocale: "en" as "en" | "fa",
  organizations: "off" as "off" | "optional" | "required",
  supervisors: "off" as "off" | "optional" | "required",
} as const;

export type FeatureMode = "off" | "optional" | "required";
export type UiLocale = "en" | "fa";
export type WebFeatures = typeof features;

export function organizationsEnabled(): boolean {
  return features.organizations !== "off";
}

export function organizationsRequired(): boolean {
  return features.organizations === "required";
}

export function supervisorsEnabled(): boolean {
  return features.supervisors !== "off";
}

export function supervisorsRequired(): boolean {
  return features.supervisors === "required";
}

export function availableLocales(): readonly UiLocale[] {
  if (features.multiLanguage) return ["en", "fa"] as const;
  return [features.defaultLocale] as const;
}

export function isRtlLocale(locale: string): boolean {
  return locale === "fa";
}