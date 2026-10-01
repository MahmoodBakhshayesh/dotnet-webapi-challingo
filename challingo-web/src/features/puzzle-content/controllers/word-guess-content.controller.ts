"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";
import { ContentStatus, type BulkAddResultDto } from "@/features/puzzle-content/repositories/puzzle-content.repository";
import { addWordGuessAnswersUseCase } from "@/features/puzzle-content/usecases/add-word-guess-answers.usecase";
import { listContentUseCase } from "@/features/puzzle-content/usecases/list-content.usecase";
import { setContentStatusUseCase } from "@/features/puzzle-content/usecases/set-content-status.usecase";
import { queryKeys } from "@/lib/query-keys";
import { toastError } from "@/lib/toast-error";

const GAME = "word-guess";

/** Word Guess answers: paste many words, review drafts, approve or retire. */
export function useWordGuessContentController() {
  const qc = useQueryClient();
  const [status, setStatus] = useState<ContentStatus | undefined>(undefined);
  const [words, setWords] = useState("");
  const [approveOnAdd, setApproveOnAdd] = useState(false);
  const [lastResult, setLastResult] = useState<BulkAddResultDto | null>(null);

  const listQuery = useQuery({
    queryKey: queryKeys.content(GAME, status),
    queryFn: () => listContentUseCase(GAME, status),
  });

  const addMutation = useMutation({
    mutationFn: () => {
      if (!words.trim()) throw new Error("Paste at least one word.");
      return addWordGuessAnswersUseCase({ words, approve: approveOnAdd });
    },
    onSuccess: async (result) => {
      setLastResult(result);
      toast.success(`${result.added} added${result.duplicates ? `, ${result.duplicates} already there` : ""}`);
      if (result.errors.length === 0) setWords("");
      await qc.invalidateQueries({ queryKey: queryKeys.contentAll });
    },
    onError: (e: Error) => toastError(e, "Could not add words"),
  });

  const statusMutation = useMutation({
    mutationFn: setContentStatusUseCase,
    onSuccess: async (item) => {
      toast.success(`${item.contentKey.toUpperCase()} ${item.status === ContentStatus.Approved ? "approved" : "retired"}`);
      await qc.invalidateQueries({ queryKey: queryKeys.contentAll });
    },
    onError: (e: Error) => toastError(e, "Could not update"),
  });

  return {
    viewState: {
      items: listQuery.data ?? [],
      isLoading: listQuery.isLoading,
      errorMessage: listQuery.isError ? (listQuery.error as Error).message : null,
      status,
      words,
      approveOnAdd,
      lastResult,
    },
    actions: {
      setStatus,
      setWords,
      setApproveOnAdd,
      add: () => addMutation.mutate(),
      approve: (id: string) => statusMutation.mutate({ id, action: "approve" }),
      retire: (id: string) => statusMutation.mutate({ id, action: "retire" }),
    },
    pending: { add: addMutation.isPending, status: statusMutation.isPending },
  };
}

export type WordGuessContentViewModel = ReturnType<typeof useWordGuessContentController>;
