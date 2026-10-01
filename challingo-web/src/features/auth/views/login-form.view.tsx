"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { GoogleSignInButton } from "@/features/auth/components/google-sign-in-button";
import type { LoginViewModel } from "@/features/auth/controllers/login.controller";

/** Presentational: reads only `viewState` + invokes `actions`. No repos / use cases. */
export function LoginFormView({ viewState, actions, pending }: LoginViewModel) {
  const t = useTranslations("Auth");
  const [googleLoadFailed, setGoogleLoadFailed] = useState(false);

  return (
    <Card className="w-full max-w-md border shadow-lg">
      <CardHeader className="space-y-1">
        <CardTitle className="text-2xl font-semibold tracking-tight">
          {t("loginTitle")}
        </CardTitle>
        <CardDescription>
          {t("subtitleApi")} ({viewState.apiBaseUrl})
        </CardDescription>
      </CardHeader>
      <CardContent>
        <Tabs defaultValue="password" className="w-full">
          <TabsList className="grid w-full grid-cols-3">
            <TabsTrigger value="password">{t("tabsPassword")}</TabsTrigger>
            <TabsTrigger value="otp">{t("tabsEmailCode")}</TabsTrigger>
            <TabsTrigger value="google">{t("tabsGoogle")}</TabsTrigger>
          </TabsList>

          <TabsContent value="password" className="mt-4 space-y-4">
            <div className="space-y-2">
              <Label htmlFor="username">{t("username")}</Label>
              <Input
                id="username"
                autoComplete="username"
                value={viewState.username}
                onChange={(e) => actions.setUsername(e.target.value)}
                placeholder={t("usernamePlaceholder")}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password">{t("password")}</Label>
              <Input
                id="password"
                type="password"
                autoComplete="current-password"
                value={viewState.password}
                onChange={(e) => actions.setPassword(e.target.value)}
              />
            </div>
            <Button
              className="w-full"
              disabled={pending.password}
              onClick={() => actions.loginPassword()}
            >
              {pending.password ? t("signingIn") : t("signIn")}
            </Button>
          </TabsContent>

          <TabsContent value="otp" className="mt-4 space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email">{t("email")}</Label>
              <Input
                id="email"
                type="email"
                value={viewState.email}
                onChange={(e) => actions.setEmail(e.target.value)}
                placeholder={t("emailPlaceholder")}
              />
            </div>
            {!viewState.otpSent ? (
              <Button
                type="button"
                variant="secondary"
                className="w-full"
                disabled={pending.sendOtp || !viewState.email.trim()}
                onClick={() => actions.sendOtp()}
              >
                {pending.sendOtp ? t("sending") : t("sendCode")}
              </Button>
            ) : (
              <>
                <div className="space-y-2">
                  <Label htmlFor="code">{t("otpCodeLabel")}</Label>
                  <Input
                    id="code"
                    inputMode="numeric"
                    value={viewState.code}
                    onChange={(e) => actions.setCode(e.target.value)}
                    placeholder="000000"
                  />
                </div>
                <Button
                  className="w-full"
                  disabled={pending.verifyOtp}
                  onClick={() => actions.verifyOtp()}
                >
                  {pending.verifyOtp ? t("verifying") : t("verifySignIn")}
                </Button>
                <Button
                  type="button"
                  variant="link"
                  className="px-0 text-sm"
                  onClick={() => actions.resetOtpFlow()}
                >
                  {t("useDifferentEmail")}
                </Button>
              </>
            )}
          </TabsContent>

          <TabsContent value="google" className="mt-4 space-y-4">
            <p className="text-muted-foreground text-sm">{t("googleTabHelp")}</p>

            {!viewState.googleClientId ? (
              <p className="rounded-md border border-dashed bg-muted/50 px-3 py-2 text-muted-foreground text-xs leading-relaxed">
                {t("googleNotConfigured")}
              </p>
            ) : (
              <>
                <GoogleSignInButton
                  clientId={viewState.googleClientId}
                  disabled={pending.google}
                  onCredential={(token) => actions.loginGoogle(token)}
                  onLoadError={() => setGoogleLoadFailed(true)}
                />
                {pending.google ? (
                  <p className="text-center text-muted-foreground text-sm">{t("signingIn")}</p>
                ) : null}
                {googleLoadFailed ? (
                  <p className="text-destructive text-sm">{t("googleLoadFailed")}</p>
                ) : null}
              </>
            )}
          </TabsContent>
        </Tabs>
      </CardContent>
    </Card>
  );
}
