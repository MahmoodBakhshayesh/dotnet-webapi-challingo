import { organizationsRepository } from "@/features/organizations/repositories/organizations.repository";
import type { OrganizationDto } from "@/features/organizations/repositories/organizations.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function listOrganizationsUseCase(): Promise<OrganizationDto[]> {
  const res = await organizationsRepository.list();
  if (!isAppSuccess(res)) throw new Error(appErrorMessage(res));
  return res.body ?? [];
}
