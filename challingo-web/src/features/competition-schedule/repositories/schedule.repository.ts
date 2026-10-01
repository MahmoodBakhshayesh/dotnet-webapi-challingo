/**
 * Data source: admin schedule endpoints (Challingo API).
 * No business rules — transport only.
 */
import { apiJson } from "@/lib/api-client";

/** Matches the API's ChallengeKind (serialized as a number). */
export enum ChallengeKind {
  Practice = 0,
  Daily = 1,
  Ranked = 2,
  Grand = 3,
}

/** Matches the API's ChallengeState. */
export enum ChallengeState {
  Upcoming = 0,
  Open = 1,
  Closed = 2,
}

export type ScheduleEntryDto = {
  challengeId: string;
  kind: ChallengeKind;
  slotKey: string;
  sequence: number;
  gameKey: string;
  difficulty: number;
  localDate?: string | null;
  opensAtUtc: string;
  closesAtUtc: string;
  state: ChallengeState;
  attempts: number;
  finalized: boolean;
};

export type CompetitionRunDto = {
  scheduled: number;
  announced: number;
  finalized: number;
  daysClosed: number;
  weeksClosed: number;
};

export const scheduleRepository = {
  list(fromUtc: string, toUtc: string) {
    const q = new URLSearchParams({ from: fromUtc, to: toUtc });
    return apiJson<ScheduleEntryDto[]>(`/api/admin/schedule?${q}`);
  },
  swap(challengeId: string, gameKey: string | null) {
    return apiJson<ScheduleEntryDto>(`/api/admin/schedule/${challengeId}/swap`, {
      method: "POST",
      body: JSON.stringify({ gameKey }),
    });
  },
  run() {
    return apiJson<CompetitionRunDto>("/api/admin/schedule/run", { method: "POST" });
  },
};
