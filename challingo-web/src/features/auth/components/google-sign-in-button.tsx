"use client";

import { useEffect, useRef, useState } from "react";

const GSI_SCRIPT_SRC = "https://accounts.google.com/gsi/client";

function loadGsiScript(): Promise<void> {
  if (window.google?.accounts?.id) {
    return Promise.resolve();
  }

  return new Promise((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(
      `script[src="${GSI_SCRIPT_SRC}"]`,
    );
    if (existing) {
      existing.addEventListener("load", () => resolve(), { once: true });
      existing.addEventListener(
        "error",
        () => reject(new Error("Failed to load Google Sign-In")),
        { once: true },
      );
      return;
    }

    const script = document.createElement("script");
    script.src = GSI_SCRIPT_SRC;
    script.async = true;
    script.defer = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("Failed to load Google Sign-In"));
    document.head.appendChild(script);
  });
}

type GoogleSignInButtonProps = {
  clientId: string;
  disabled?: boolean;
  onCredential: (idToken: string) => void;
  onLoadError?: () => void;
};

/** Renders the official Google Identity Services sign-in button. */
export function GoogleSignInButton({
  clientId,
  disabled = false,
  onCredential,
  onLoadError,
}: GoogleSignInButtonProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const onCredentialRef = useRef(onCredential);
  const [ready, setReady] = useState(false);

  onCredentialRef.current = onCredential;

  useEffect(() => {
    if (disabled) {
      setReady(false);
      return;
    }

    let cancelled = false;

    loadGsiScript()
      .then(() => {
        if (cancelled || !containerRef.current || !window.google?.accounts?.id) {
          return;
        }

        const container = containerRef.current;
        container.innerHTML = "";

        window.google.accounts.id.initialize({
          client_id: clientId,
          callback: (response) => {
            if (response.credential) {
              onCredentialRef.current(response.credential);
            }
          },
        });

        const width = Math.min(400, Math.max(240, container.offsetWidth || 320));
        window.google.accounts.id.renderButton(container, {
          theme: "outline",
          size: "large",
          text: "continue_with",
          shape: "rectangular",
          width,
        });

        setReady(true);
      })
      .catch(() => {
        if (!cancelled) {
          onLoadError?.();
        }
      });

    return () => {
      cancelled = true;
      setReady(false);
    };
  }, [clientId, disabled, onLoadError]);

  return (
    <div
      className={
        disabled
          ? "pointer-events-none opacity-60"
          : ready
            ? undefined
            : "min-h-10 animate-pulse rounded-md bg-muted"
      }
    >
      <div ref={containerRef} className="flex w-full justify-center [&>div]:!w-full" />
    </div>
  );
}
