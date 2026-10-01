"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { toast } from "sonner";
import { toastError } from "@/lib/toast-error";
import { loginWithGoogleUseCase } from "@/features/auth/usecases/login-with-google.usecase";
import { loginWithPasswordUseCase } from "@/features/auth/usecases/login-with-password.usecase";
import { requestOtpUseCase } from "@/features/auth/usecases/request-otp.usecase";
import { verifyOtpUseCase } from "@/features/auth/usecases/verify-otp.usecase";
import { getApiBaseUrl, getGoogleClientId } from "@/lib/env";
import { mergeRolesFromJwt } from "@/lib/jwt-roles";
import { getPostLoginRoute } from "@/lib/roles";
import { useAuthStore } from "@/stores/auth-store";

/** Orchestrates login view: owns transient UI state and calls use cases (never repos). */
export function useLoginController() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const setSession = useAuthStore((s) => s.setSession);
  const t = useTranslations("Auth");

  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [otpSent, setOtpSent] = useState(false);

  const passwordMutation = useMutation({
    mutationFn: () => loginWithPasswordUseCase(username, password),
    onSuccess: (body) => {
      setSession(body);
      void queryClient.invalidateQueries();
      toast.success(t("welcomeBack"));
      const roles = mergeRolesFromJwt(body.roles ?? [], body.token.accessToken);
      router.replace(getPostLoginRoute(roles));
    },
    onError: (e: Error) => toastError(e, t("loginFailed")),
  });

  const googleMutation = useMutation({
    mutationFn: (idToken: string) => loginWithGoogleUseCase(idToken),
    onSuccess: (body) => {
      setSession(body);
      void queryClient.invalidateQueries();
      toast.success(t("signedInGoogle"));
      const roles = mergeRolesFromJwt(body.roles ?? [], body.token.accessToken);
      router.replace(getPostLoginRoute(roles));
    },
    onError: (e: Error) => toastError(e, t("loginFailed")),
  });

  const requestOtpMutation = useMutation({
    mutationFn: () => requestOtpUseCase(email.trim()),
    onSuccess: () => {
      setOtpSent(true);
      toast.message(t("otpSent"));
    },
    onError: (e: Error) => toastError(e, t("loginFailed")),
  });

  const verifyOtpMutation = useMutation({
    mutationFn: () => verifyOtpUseCase(email.trim(), code.trim()),
    onSuccess: (body) => {
      setSession(body);
      void queryClient.invalidateQueries();
      toast.success(t("signedIn"));
      const roles = mergeRolesFromJwt(body.roles ?? [], body.token.accessToken);
      router.replace(getPostLoginRoute(roles));
    },
    onError: (e: Error) => toastError(e, t("loginFailed")),
  });

  return {
    viewState: {
      username,
      password,
      email,
      code,
      otpSent,
      googleClientId: getGoogleClientId(),
      apiBaseUrl: getApiBaseUrl(),
    },
    actions: {
      setUsername,
      setPassword,
      setEmail,
      setCode,
      sendOtp: () => requestOtpMutation.mutate(),
      verifyOtp: () => verifyOtpMutation.mutate(),
      loginPassword: () => passwordMutation.mutate(),
      loginGoogle: (idToken: string) => googleMutation.mutate(idToken),
      resetOtpFlow: () => {
        setOtpSent(false);
        setCode("");
      },
    },
    pending: {
      password: passwordMutation.isPending,
      google: googleMutation.isPending,
      sendOtp: requestOtpMutation.isPending,
      verifyOtp: verifyOtpMutation.isPending,
    },
  };
}

export type LoginViewModel = ReturnType<typeof useLoginController>;
