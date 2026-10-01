"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";
import {
  listDayScheduleUseCase,
  runCompetitionUseCase,
  swapPuzzleUseCase,
} from "@/features/competition-schedule/usecases/schedule.usecases";
import { listGamesUseCase } from "@/features/puzzle-content/usecases/list-games.usecase";
import { queryKeys } from "@/lib/query-keys";
import { toastError } from "@/lib/toast-error";

const todayUtc = () => new Date().toISOString().slice(0, 10);

function shiftDate(date: string, days: number) {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/** One UTC day of the competition schedule: preview, swap unopened puzzles, run the jobs now. */
export function useScheduleController() {
  const queryClient = useQueryClient();
  const [date, setDate] = useState(todayUtc);

  const scheduleQuery = useQuery({ queryKey: queryKeys.schedule(date), queryFn: () => listDayScheduleUseCase(date) });
  const gamesQuery = useQuery({ queryKey: queryKeys.games, queryFn: listGamesUseCase });

  const swapMutation = useMutation({
    mutationFn: swapPuzzleUseCase,
    onSuccess: (entry) => {
      toast.success(`${entry.slotKey} is now ${entry.gameKey}`);
      void queryClient.invalidateQueries({ queryKey: queryKeys.scheduleAll });
    },
    onError: (e: Error) => toastError(e, "Could not swap the puzzle"),
  });

  const runMutation = useMutation({
    mutationFn: runCompetitionUseCase,
    onSuccess: (r) => {
      toast.success(
        `Scheduled ${r.scheduled}, announced ${r.announced}, finalized ${r.finalized}, closed ${r.daysClosed} days and ${r.weeksClosed} weeks`,
      );
      void queryClient.invalidateQueries({ queryKey: queryKeys.scheduleAll });
    },
    onError: (e: Error) => toastError(e, "Could not run the competition jobs"),
  });

  return {
    viewState: {
      date,
      entries: scheduleQuery.data ?? [],
      games: gamesQuery.data ?? [],
      loading: scheduleQuery.isLoading,
      error: scheduleQuery.error ? (scheduleQuery.error as Error).message : null,
      isSunday: new Date(`${date}T00:00:00Z`).getUTCDay() === 0,
    },
    actions: {
      setDate,
      previousDay: () => setDate((d) => shiftDate(d, -1)),
      nextDay: () => setDate((d) => shiftDate(d, 1)),
      today: () => setDate(todayUtc()),
      swap: (challengeId: string, gameKey: string | null) => swapMutation.mutate({ challengeId, gameKey }),
      run: () => runMutation.mutate(),
    },
    pending: {
      swapId: swapMutation.isPending ? swapMutation.variables?.challengeId : undefined,
      run: runMutation.isPending,
    },
  };
}

export type ScheduleViewModel = ReturnType<typeof useScheduleController>;
