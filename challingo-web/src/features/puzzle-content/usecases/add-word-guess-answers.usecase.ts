import {
  puzzleContentRepository,
  type BulkAddResultDto,
} from "@/features/puzzle-content/repositories/puzzle-content.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function addWordGuessAnswersUseCase(input: { words: string; approve: boolean }): Promise<BulkAddResultDto> {
  const res = await puzzleContentRepository.addWordGuessAnswers(input);
  if (!isAppSuccess(res) || !res.body) throw new Error(appErrorMessage(res));
  return res.body;
}
