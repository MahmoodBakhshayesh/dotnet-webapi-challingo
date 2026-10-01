import { usersRepository } from "@/features/users/repositories/users.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function deleteUserUseCase(id: string): Promise<void> {
  const res = await usersRepository.remove(id);
  if (!isAppSuccess(res) && res.status !== 204) {
    throw new Error(appErrorMessage(res));
  }
}
