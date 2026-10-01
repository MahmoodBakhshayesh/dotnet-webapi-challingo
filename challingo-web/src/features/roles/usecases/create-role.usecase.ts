import { rolesRepository } from "@/features/roles/repositories/roles.repository";
import type {
  RoleDto,
  RolePermissionDto,
} from "@/features/roles/repositories/roles.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function createRoleUseCase(body: {
  name: string;
  permissions: RolePermissionDto[];
}): Promise<RoleDto> {
  const res = await rolesRepository.create(body);
  if (!isAppSuccess(res) || res.body == null) throw new Error(appErrorMessage(res));
  return res.body;
}
