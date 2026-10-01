import {
  puzzleContentRepository,
  type PuzzlePreviewDto,
} from "@/features/puzzle-content/repositories/puzzle-content.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function previewPuzzleUseCase(input: { gameKey: string; difficulty: number; seed?: number }): Promise<PuzzlePreviewDto> {
  const res = await puzzleContentRepository.preview(input.gameKey, input.difficulty, input.seed);
  if (!isAppSuccess(res) || !res.body) throw new Error(appErrorMessage(res));
  return res.body;
}
