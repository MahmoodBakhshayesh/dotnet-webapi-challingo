"use client";

import { useMutation, useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { listGamesUseCase } from "@/features/puzzle-content/usecases/list-games.usecase";
import { previewPuzzleUseCase } from "@/features/puzzle-content/usecases/preview-puzzle.usecase";
import { queryKeys } from "@/lib/query-keys";
import { toastError } from "@/lib/toast-error";

/** Generates a puzzle on demand (nothing stored) so admins can check a game and its difficulty levels. */
export function usePuzzlePreviewController() {
  const [gameKey, setGameKey] = useState("sudoku");
  const [difficulty, setDifficulty] = useState(1);
  const [seed, setSeed] = useState("");

  const gamesQuery = useQuery({ queryKey: queryKeys.games, queryFn: listGamesUseCase });

  const previewMutation = useMutation({
    mutationFn: () => {
      const parsed = seed.trim() === "" ? undefined : Number(seed);
      if (parsed !== undefined && (!Number.isInteger(parsed) || parsed < 0)) throw new Error("Seed must be a whole number.");
      return previewPuzzleUseCase({ gameKey, difficulty, seed: parsed });
    },
    onError: (e: Error) => toastError(e, "Could not generate a puzzle"),
  });

  return {
    viewState: {
      games: gamesQuery.data ?? [],
      gameKey,
      difficulty,
      seed,
      preview: previewMutation.data ?? null,
    },
    actions: {
      setGameKey,
      setDifficulty,
      setSeed,
      generate: () => previewMutation.mutate(),
      // Re-run the shown puzzle (handy after a deploy, to confirm a seed still produces the same board).
      regenerate: () => {
        if (previewMutation.data) setSeed(String(previewMutation.data.seed));
        previewMutation.mutate();
      },
    },
    pending: { generate: previewMutation.isPending },
  };
}

export type PuzzlePreviewViewModel = ReturnType<typeof usePuzzlePreviewController>;
