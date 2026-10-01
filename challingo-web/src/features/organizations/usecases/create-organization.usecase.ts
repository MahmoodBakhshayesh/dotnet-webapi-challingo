import { organizationsRepository } from "@/features/organizations/repositories/organizations.repository";
import type { OrganizationDto } from "@/features/organizations/repositories/organizations.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function createOrganizationUseCase(body: {
  name: string;
}): Promise<OrganizationDto> {
  const res = await organizationsRepository.create(body);
  if (!isAppSuccess(res) || res.body == null) throw new Error(appErrorMessage(res));
  return res.body;
}
