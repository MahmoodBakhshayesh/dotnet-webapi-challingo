"use client";

import { useTranslations } from "next-intl";
import Link from "next/link";
import { motion, useReducedMotion } from "motion/react";
import {
  UsersThree,
  ShieldCheck,
  RocketLaunch,
} from "@phosphor-icons/react";
import { LocaleSwitcher } from "@/components/locale-switcher";
import { buttonVariants } from "@/components/ui/button";
import { Magnetic } from "@/components/motion/magnetic";
import { Reveal, RevealItem } from "@/components/motion/reveal";
import { CountUp } from "@/components/motion/count-up";
import { Marquee } from "@/components/motion/marquee";
import { ScrollSteps } from "@/components/motion/scroll-steps";
import { fadeUp } from "@/lib/motion";
import { cn } from "@/lib/utils";
import { features } from "@/config/features";

const FEATURES = [
  { key: "featureUsers" as const, Icon: UsersThree },
  { key: "featureRoles" as const, Icon: ShieldCheck },
  { key: "featureReady" as const, Icon: RocketLaunch },
];

const STATS = [
  { value: 4200, suffix: "+", label: "statUsers" as const },
  { value: 180, suffix: "+", label: "statOrgs" as const },
  { value: 99.9, suffix: "%", label: "statUptime" as const, decimals: 1 },
];

const TRUST = ["trust1", "trust2", "trust3", "trust4", "trust5"] as const;

export function LandingPage() {
  const t = useTranslations("Landing");
  const reduceMotion = useReducedMotion();

  const steps = (
    [
      { id: "step-1", label: "step1Label" as const, body: "step1Body" as const },
      { id: "step-2", label: "step2Label" as const, body: "step2Body" as const },
      { id: "step-3", label: "step3Label" as const, body: "step3Body" as const },
    ] as const
  ).map((step) => ({
    id: step.id,
    label: t(step.label),
    content: (
      <div className="space-y-3">
        <h3 className="text-xl font-semibold tracking-tight md:text-2xl">{t(step.label)}</h3>
        <p className="text-muted-foreground max-w-xl leading-relaxed">{t(step.body)}</p>
      </div>
    ),
  }));

  return (
    <div className="relative flex min-h-screen flex-col overflow-x-hidden bg-background">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-primary/15 via-background to-background"
      />

      <header className="relative z-10 flex items-center justify-between gap-4 px-6 py-5 md:px-10">
        <span className="text-lg font-semibold tracking-tight">{t("brand")}</span>
        <div className="flex items-center gap-3">
          <LocaleSwitcher />
          {features.loginPage ? (
            <Link href="/login" className={cn(buttonVariants({ size: "sm" }))}>
              {t("signIn")}
            </Link>
          ) : null}
        </div>
      </header>

      <motion.main
        className="relative z-10 mx-auto flex w-full max-w-5xl flex-1 flex-col gap-20 px-6 pb-24 md:px-10"
        initial={reduceMotion ? false : "hidden"}
        animate="show"
        variants={fadeUp}
      >
        <section className="flex max-w-3xl flex-col gap-6 pt-10 md:pt-16">
          <h1 className="text-4xl font-bold tracking-tight md:text-5xl">{t("headline")}</h1>
          <p className="text-muted-foreground max-w-xl text-base md:text-lg">{t("subtitle")}</p>
          <div className="flex flex-wrap gap-3">
            {features.loginPage ? (
              <Magnetic>
                <Link href="/login" className={cn(buttonVariants({ size: "lg" }))}>
                  {t("ctaPrimary")}
                </Link>
              </Magnetic>
            ) : null}
          </div>
        </section>

        <Reveal stagger className="grid gap-4 sm:grid-cols-3">
          {FEATURES.map(({ key, Icon }) => (
            <RevealItem
              key={key}
              className="border-border/60 bg-card/40 flex flex-col gap-3 rounded-2xl border p-5 shadow-sm"
            >
              <Icon className="text-primary size-8" weight="duotone" />
              <p className="text-sm font-medium leading-snug">{t(key)}</p>
            </RevealItem>
          ))}
        </Reveal>

        <section>
          <Reveal className="mb-8">
            <h2 className="text-2xl font-semibold tracking-tight">{t("statsTitle")}</h2>
          </Reveal>
          <Reveal stagger className="grid grid-cols-1 gap-8 sm:grid-cols-3">
            {STATS.map((stat) => (
              <RevealItem key={stat.label} className="space-y-1">
                <p className="text-3xl font-semibold tracking-tight md:text-4xl">
                  <CountUp
                    value={stat.value}
                    suffix={stat.suffix}
                    decimals={"decimals" in stat ? stat.decimals : 0}
                  />
                </p>
                <p className="text-muted-foreground text-sm">{t(stat.label)}</p>
              </RevealItem>
            ))}
          </Reveal>
        </section>

        <section>
          <Reveal className="mb-8">
            <h2 className="text-2xl font-semibold tracking-tight">{t("processTitle")}</h2>
          </Reveal>
          <ScrollSteps steps={steps} />
        </section>
      </motion.main>

      <section className="relative z-10 border-y border-border/50 py-10">
        <div className="mx-auto mb-6 max-w-5xl px-6 md:px-10">
          <p className="text-muted-foreground text-sm font-medium tracking-wide uppercase">
            {t("trustTitle")}
          </p>
        </div>
        <Marquee duration={32} className="[--gap:2.5rem]">
          {TRUST.map((key) => (
            <span
              key={key}
              className="border-border/50 text-muted-foreground inline-flex shrink-0 items-center rounded-full border px-5 py-2 text-sm whitespace-nowrap"
            >
              {t(key)}
            </span>
          ))}
        </Marquee>
      </section>
    </div>
  );
}
