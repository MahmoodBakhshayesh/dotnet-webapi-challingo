import {
  puzzleContentRepository,
  type ContentItemDto,
  type ContentStatus,
} from "@/features/puzzle-content/repositories/puzzle-content.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function listContentUseCase(gameKey: string, status?: ContentStatus): Promise<ContentItemDto[]> {
  const res = await puzzleContentRepository.list(gameKey, status);
  if (!isAppSuccess(res)) throw new Error(appErrorMessage(res));
  return res.body ?? [];
}
