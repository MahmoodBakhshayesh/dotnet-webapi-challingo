import {
  puzzleContentRepository,
  type ContentItemDto,
} from "@/features/puzzle-content/repositories/puzzle-content.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function addContentUseCase(input: {
  gameKey: string;
  payload: unknown;
  notes?: string;
  approve: boolean;
}): Promise<ContentItemDto> {
  const res = await puzzleContentRepository.add(input.gameKey, {
    payload: input.payload,
    notes: input.notes,
    approve: input.approve,
  });
  if (!isAppSuccess(res) || !res.body) throw new Error(appErrorMessage(res));
  return res.body;
}
