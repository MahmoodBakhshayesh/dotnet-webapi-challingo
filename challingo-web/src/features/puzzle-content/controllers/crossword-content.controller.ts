"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { toast } from "sonner";
import { layoutCrossword, type CrosswordPayload } from "@/features/puzzle-content/lib/crossword-layout";
import { ContentStatus } from "@/features/puzzle-content/repositories/puzzle-content.repository";
import { addContentUseCase } from "@/features/puzzle-content/usecases/add-content.usecase";
import { listContentUseCase } from "@/features/puzzle-content/usecases/list-content.usecase";
import { setContentStatusUseCase } from "@/features/puzzle-content/usecases/set-content-status.usecase";
import { queryKeys } from "@/lib/query-keys";
import { toastError } from "@/lib/toast-error";

const GAME = "mini-crossword";
const BLOCK = "#";

/** Mini Crossword bank: build a grid with clues, review drafts, approve or retire. */
export function useCrosswordContentController() {
  const qc = useQueryClient();
  const [status, setStatus] = useState<ContentStatus | undefined>(undefined);
  const [width, setWidth] = useState(5);
  const [height, setHeight] = useState(5);
  const [cells, setCells] = useState<string[]>(() => Array(25).fill(""));
  const [clues, setClues] = useState<Record<string, string>>({}); // key: "12A" / "3D"
  const [notes, setNotes] = useState("");
  const [approve, setApprove] = useState(false);

  // Numbering treats empty cells as white, so clue boxes appear while the grid is being filled.
  const rows = useMemo(
    () => Array.from({ length: height }, (_, r) => cells.slice(r * width, (r + 1) * width).map((c) => (c === BLOCK ? BLOCK : "A")).join("")),
    [cells, width, height],
  );
  const entries = useMemo(() => layoutCrossword(rows), [rows]);
  const numbers = useMemo(() => new Map(entries.map((e) => [e.cells[0], e.number])), [entries]);
  const missingLetters = cells.some((c) => c === "");
  const missingClues = entries.some((e) => !clues[`${e.number}${e.across ? "A" : "D"}`]?.trim());

  const listQuery = useQuery({
    queryKey: queryKeys.content(GAME, status),
    queryFn: () => listContentUseCase(GAME, status),
  });

  const saveMutation = useMutation({
    mutationFn: () => {
      if (missingLetters) throw new Error("Fill every square with a letter, or make it a block (#).");
      if (missingClues) throw new Error("Every entry needs a clue.");
      const payload: CrosswordPayload = {
        rows: Array.from({ length: height }, (_, r) => cells.slice(r * width, (r + 1) * width).join("")),
        clues: { across: {}, down: {} },
      };
      for (const e of entries) {
        payload.clues[e.across ? "across" : "down"][String(e.number)] = clues[`${e.number}${e.across ? "A" : "D"}`].trim();
      }
      return addContentUseCase({ gameKey: GAME, payload, notes: notes.trim() || undefined, approve });
    },
    onSuccess: async () => {
      toast.success(approve ? "Crossword approved" : "Crossword saved as draft");
      reset(width, height);
      await qc.invalidateQueries({ queryKey: queryKeys.contentAll });
    },
    onError: (e: Error) => toastError(e, "Could not save crossword"),
  });

  const statusMutation = useMutation({
    mutationFn: setContentStatusUseCase,
    onSuccess: async () => {
      toast.success("Updated");
      await qc.invalidateQueries({ queryKey: queryKeys.contentAll });
    },
    onError: (e: Error) => toastError(e, "Could not update"),
  });

  function reset(w: number, h: number) {
    setWidth(w);
    setHeight(h);
    setCells(Array(w * h).fill(""));
    setClues({});
    setNotes("");
  }

  return {
    viewState: {
      items: listQuery.data ?? [],
      isLoading: listQuery.isLoading,
      errorMessage: listQuery.isError ? (listQuery.error as Error).message : null,
      status,
      width,
      height,
      cells,
      entries,
      numbers,
      clues,
      notes,
      approve,
      canSave: !missingLetters && !missingClues,
    },
    actions: {
      setStatus,
      resize: (w: number, h: number) => reset(w, h),
      setCell: (index: number, raw: string) => {
        const ch = raw.slice(-1).toUpperCase();
        const value = ch === "." || ch === BLOCK ? BLOCK : /^[A-Z]$/.test(ch) ? ch : "";
        setCells((prev) => prev.map((c, i) => (i === index ? value : c)));
      },
      toggleBlock: (index: number) => setCells((prev) => prev.map((c, i) => (i === index ? (c === BLOCK ? "" : BLOCK) : c))),
      setClue: (key: string, text: string) => setClues((prev) => ({ ...prev, [key]: text })),
      setNotes,
      setApprove,
      save: () => saveMutation.mutate(),
      approveItem: (id: string) => statusMutation.mutate({ id, action: "approve" }),
      retireItem: (id: string) => statusMutation.mutate({ id, action: "retire" }),
    },
    pending: { save: saveMutation.isPending, status: statusMutation.isPending },
  };
}

export type CrosswordContentViewModel = ReturnType<typeof useCrosswordContentController>;
