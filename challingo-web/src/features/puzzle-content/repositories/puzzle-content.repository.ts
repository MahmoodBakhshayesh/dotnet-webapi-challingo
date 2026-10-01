/**
 * Data source: admin content + puzzle preview endpoints (Challingo API).
 * No business rules — transport only.
 */
import { apiJson } from "@/lib/api-client";

/** Matches the API's ContentStatus (serialized as a number). */
export enum ContentStatus {
  Draft = 0,
  Approved = 1,
  Retired = 2,
}

export type ContentItemDto = {
  id: string;
  gameKey: string;
  contentKey: string;
  status: ContentStatus;
  payload: unknown;
  notes?: string | null;
  createdAt: string;
  reviewedAtUtc?: string | null;
};

export type BulkAddResultDto = { added: number; duplicates: number; errors: string[] };

export type PuzzlePreviewDto = {
  gameKey: string;
  seed: number;
  difficulty: number;
  puzzle: Record<string, unknown>;
  secret: Record<string, unknown>;
};

export const puzzleContentRepository = {
  list(gameKey: string, status?: ContentStatus) {
    const q = status === undefined ? "" : `?status=${status}`;
    return apiJson<ContentItemDto[]>(`/api/admin/content/${gameKey}${q}`);
  },
  add(gameKey: string, body: { payload: unknown; notes?: string; approve: boolean }) {
    return apiJson<ContentItemDto>(`/api/admin/content/${gameKey}`, {
      method: "POST",
      body: JSON.stringify(body),
    });
  },
  addWordGuessAnswers(body: { words: string; approve: boolean }) {
    return apiJson<BulkAddResultDto>("/api/admin/content/word-guess/bulk", {
      method: "POST",
      body: JSON.stringify(body),
    });
  },
  setStatus(id: string, action: "approve" | "retire") {
    return apiJson<ContentItemDto>(`/api/admin/content/items/${id}/${action}`, { method: "POST" });
  },
  preview(gameKey: string, difficulty: number, seed?: number) {
    const q = new URLSearchParams({ difficulty: String(difficulty) });
    if (seed !== undefined) q.set("seed", String(seed));
    return apiJson<PuzzlePreviewDto>(`/api/admin/puzzles/${gameKey}/preview?${q}`);
  },
  games() {
    return apiJson<string[]>("/api/challenges/games");
  },
};
