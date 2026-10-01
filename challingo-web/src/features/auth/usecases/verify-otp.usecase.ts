import { authRepository } from "@/features/auth/repositories/auth.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";
import type { UserLoginResponse } from "@/types/api";

export async function verifyOtpUseCase(
  email: string,
  code: string,
): Promise<UserLoginResponse> {
  const res = await authRepository.verifyOtp(email, code);
  if (!isAppSuccess(res) || !res.body) throw new Error(appErrorMessage(res));
  return res.body;
}
