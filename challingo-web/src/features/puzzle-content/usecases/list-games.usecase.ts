import { puzzleContentRepository } from "@/features/puzzle-content/repositories/puzzle-content.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function listGamesUseCase(): Promise<string[]> {
  const res = await puzzleContentRepository.games();
  if (!isAppSuccess(res)) throw new Error(appErrorMessage(res));
  return res.body ?? [];
}
