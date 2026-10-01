import { authRepository } from "@/features/auth/repositories/auth.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function requestOtpUseCase(email: string): Promise<void> {
  const res = await authRepository.requestOtp(email);
  if (!isAppSuccess(res)) throw new Error(appErrorMessage(res));
}
