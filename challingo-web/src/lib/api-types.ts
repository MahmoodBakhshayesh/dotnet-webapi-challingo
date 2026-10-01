/** Matches API AppResponsePayload JSON (camelCase via Newtonsoft). */
export type AppResponse<T> = {
  status: number;
  message: string;
  problem?: unknown;
  body?: T;
};

/** ProblemDetails / ValidationProblemDetails shape from the API envelope. */
export type AppProblemDetails = {
  title?: string;
  status?: number;
  detail?: string;
  errors?: Record<string, string | string[]>;
  /** Legacy typo in ValidationExceptionHandler — kept for compatibility. */
  erros?: Record<string, string | string[]>;
  extensions?: {
    errors?: Record<string, string | string[]>;
    erros?: Record<string, string | string[]>;
    [key: string]: unknown;
  };
  traceId?: string;
};

export function isAppSuccess<T>(r: AppResponse<T>): boolean {
  return r.status > 0 && r.status < 400;
}

function collectBagMessages(bag: Record<string, string | string[]>): string[] {
  const messages: string[] = [];

  for (const value of Object.values(bag)) {
    if (typeof value === "string" && value.trim()) {
      messages.push(value.trim());
      continue;
    }
    if (Array.isArray(value)) {
      for (const item of value) {
        if (typeof item === "string" && item.trim()) messages.push(item.trim());
      }
    }
  }

  return messages;
}

function getProblemErrorBag(problem: AppProblemDetails): Record<string, string | string[]> | null {
  for (const key of ["errors", "erros"] as const) {
    const bag = problem[key];
    if (bag && typeof bag === "object") return bag;
  }

  const extensions = problem.extensions;
  if (extensions && typeof extensions === "object") {
    for (const key of ["errors", "erros"] as const) {
      const bag = extensions[key];
      if (bag && typeof bag === "object") return bag;
    }
  }

  return null;
}

/** All distinct user-facing error lines from an API error response. */
export function appErrorMessages(r: AppResponse<unknown>): string[] {
  const messages: string[] = [];

  if (r.problem && typeof r.problem === "object") {
    const problem = r.problem as AppProblemDetails;
    const detail = problem.detail?.trim();
    const bag = getProblemErrorBag(problem);
    const fieldErrors = bag ? collectBagMessages(bag) : [];

    if (detail) messages.push(detail);
    for (const err of fieldErrors) {
      if (!messages.includes(err)) messages.push(err);
    }
  }

  if (messages.length === 0) {
    const msg = r.message?.trim();
    if (msg) messages.push(msg);
  }

  return messages.length > 0 ? messages : ["Request failed"];
}

/** Single string for thrown Error (detail + field errors, newline-separated). */
export function appErrorMessage(r: AppResponse<unknown>): string {
  return appErrorMessages(r).join("\n");
}

/** One-line summary for compact UI (detail + field errors). */
export function appErrorInlineMessage(r: AppResponse<unknown>): string {
  return appErrorMessages(r).join(" • ");
}
