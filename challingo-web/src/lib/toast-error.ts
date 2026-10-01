import { toast } from "sonner";
import type { AppResponse } from "@/lib/api-types";
import { appErrorMessages } from "@/lib/api-types";

/** Show API envelope errors — title + description when multiple lines exist. */
export function toastAppError(r: AppResponse<unknown>, fallback = "Request failed") {
  const lines = appErrorMessages(r);
  if (lines.length === 0) {
    toast.error(fallback);
    return;
  }
  if (lines.length === 1) {
    toast.error(lines[0]);
    return;
  }
  toast.error(lines[0], { description: lines.slice(1).join("\n") });
}

/** Show Error from use cases (supports newline- or bullet-separated messages). */
export function toastError(err: unknown, fallback = "Request failed") {
  if (!(err instanceof Error)) {
    toast.error(fallback);
    return;
  }

  const message = err.message.trim();
  if (!message) {
    toast.error(fallback);
    return;
  }

  const parts = message
    .split(/\n| • /)
    .map((part) => part.trim())
    .filter(Boolean);

  if (parts.length <= 1) {
    toast.error(message);
    return;
  }

  toast.error(parts[0], { description: parts.slice(1).join("\n") });
}
