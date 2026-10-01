import { authRepository } from "@/features/auth/repositories/auth.repository";

/** Best-effort server logout; caller clears local session regardless. */
export async function logoutUseCase(): Promise<void> {
  try {
    await authRepository.logout();
  } catch {
    /* ignore network errors */
  }
}
