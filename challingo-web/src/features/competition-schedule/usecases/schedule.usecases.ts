import {
  scheduleRepository,
  type CompetitionRunDto,
  type ScheduleEntryDto,
} from "@/features/competition-schedule/repositories/schedule.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

/** Everything scheduled for one UTC date: its six rounds (or Sunday's Grand games) and the daily puzzle for that date. */
export async function listDayScheduleUseCase(date: string): Promise<ScheduleEntryDto[]> {
  const day = new Date(`${date}T00:00:00Z`);
  // Daily puzzles open up to 14 h early and close up to 36 h after their date starts.
  const from = new Date(day.getTime() - 24 * 3600_000).toISOString();
  const to = new Date(day.getTime() + 48 * 3600_000).toISOString();
  const res = await scheduleRepository.list(from, to);
  if (!isAppSuccess(res) || !res.body) throw new Error(appErrorMessage(res));
  return res.body
    .filter((e) => e.slotKey.includes(`:${date}`))
    .sort((a, b) => a.kind - b.kind || a.sequence - b.sequence);
}

export async function swapPuzzleUseCase(input: { challengeId: string; gameKey: string | null }): Promise<ScheduleEntryDto> {
  const res = await scheduleRepository.swap(input.challengeId, input.gameKey);
  if (!isAppSuccess(res) || !res.body) throw new Error(appErrorMessage(res));
  return res.body;
}

export async function runCompetitionUseCase(): Promise<CompetitionRunDto> {
  const res = await scheduleRepository.run();
  if (!isAppSuccess(res) || !res.body) throw new Error(appErrorMessage(res));
  return res.body;
}
