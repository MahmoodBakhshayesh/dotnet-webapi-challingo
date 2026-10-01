import { rolesRepository } from "@/features/roles/repositories/roles.repository";
import type { RoleDto } from "@/features/roles/repositories/roles.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function listRolesUseCase(): Promise<RoleDto[]> {
  const res = await rolesRepository.list();
  if (!isAppSuccess(res)) throw new Error(appErrorMessage(res));
  return res.body ?? [];
}
