import { usersRepository } from "@/features/users/repositories/users.repository";
import type { UserDto } from "@/features/users/repositories/users.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function updateUserUseCase(input: {
  id: string;
  body: {
    email?: string;
    phoneNumber?: string;
    password?: string;
    roles?: string[];
  };
}): Promise<UserDto> {
  const res = await usersRepository.update(input.id, input.body);
  if (!isAppSuccess(res) || res.body == null) throw new Error(appErrorMessage(res));
  return res.body;
}
