import { usersRepository } from "@/features/users/repositories/users.repository";
import type { UserDto } from "@/features/users/repositories/users.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function createUserUseCase(body: {
  userName: string;
  password: string;
  passwordConfirm: string;
  email?: string;
  phoneNumber?: string;
  roles?: string[];
}): Promise<UserDto> {
  const res = await usersRepository.create(body);
  if (!isAppSuccess(res) || res.body == null) throw new Error(appErrorMessage(res));
  return res.body;
}
