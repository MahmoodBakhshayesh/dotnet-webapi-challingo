import {
  puzzleContentRepository,
  type ContentItemDto,
} from "@/features/puzzle-content/repositories/puzzle-content.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function setContentStatusUseCase(input: { id: string; action: "approve" | "retire" }): Promise<ContentItemDto> {
  const res = await puzzleContentRepository.setStatus(input.id, input.action);
  if (!isAppSuccess(res) || !res.body) throw new Error(appErrorMessage(res));
  return res.body;
}
