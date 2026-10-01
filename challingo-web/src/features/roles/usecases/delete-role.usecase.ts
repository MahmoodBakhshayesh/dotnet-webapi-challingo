import { rolesRepository } from "@/features/roles/repositories/roles.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function deleteRoleUseCase(id: string): Promise<void> {
  const res = await rolesRepository.remove(id);
  if (!isAppSuccess(res) && res.status !== 204) {
    throw new Error(appErrorMessage(res));
  }
}
