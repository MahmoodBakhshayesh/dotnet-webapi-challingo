import { authRepository } from "@/features/auth/repositories/auth.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";
import type { UserLoginResponse } from "@/types/api";

export async function loginWithGoogleUseCase(
  idToken: string,
): Promise<UserLoginResponse> {
  const res = await authRepository.loginGoogle(idToken);
  if (!isAppSuccess(res) || !res.body) throw new Error(appErrorMessage(res));
  return res.body;
}
