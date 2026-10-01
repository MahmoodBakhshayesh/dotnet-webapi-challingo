import { organizationsRepository } from "@/features/organizations/repositories/organizations.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function deleteOrganizationUseCase(id: string): Promise<void> {
  const res = await organizationsRepository.remove(id);
  if (!isAppSuccess(res) && res.status !== 204) {
    throw new Error(appErrorMessage(res));
  }
}
