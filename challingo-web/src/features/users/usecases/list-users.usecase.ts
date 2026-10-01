import { usersRepository } from "@/features/users/repositories/users.repository";
import type { UserDto } from "@/features/users/repositories/users.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function listUsersUseCase(): Promise<UserDto[]> {
  const res = await usersRepository.list();
  if (!isAppSuccess(res)) throw new Error(appErrorMessage(res));
  return res.body ?? [];
}
