import { rolesRepository } from "@/features/roles/repositories/roles.repository";
import type {
  RoleDto,
  RolePermissionDto,
} from "@/features/roles/repositories/roles.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function updateRoleUseCase(input: {
  id: string;
  body: { name?: string; permissions: RolePermissionDto[] };
}): Promise<RoleDto> {
  const res = await rolesRepository.update(input.id, input.body);
  if (!isAppSuccess(res) || res.body == null) throw new Error(appErrorMessage(res));
  return res.body;
}
