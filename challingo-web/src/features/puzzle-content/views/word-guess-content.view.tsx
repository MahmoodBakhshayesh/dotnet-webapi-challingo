/** Presentational: reads only `viewState` + invokes `actions`. */
"use client";

import { SpellCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { WordGuessContentViewModel } from "@/features/puzzle-content/controllers/word-guess-content.controller";
import { ReviewActions, StatusBadge, StatusFilter } from "@/features/puzzle-content/views/content-ui";

export function WordGuessContentView({ viewState, actions, pending }: WordGuessContentViewModel) {
  return (
    <div className="space-y-6">
      <div className="flex items-start gap-3">
        <SpellCheck className="mt-1 size-6 opacity-80" />
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Word Guess answers</h1>
          <p className="text-muted-foreground text-sm">
            Only approved words become answers. Pick common words players will know; guesses are checked against the full dictionary.
          </p>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Add answers</CardTitle>
          <CardDescription>Paste five-letter words separated by new lines, commas or spaces. Words outside the dictionary are rejected.</CardDescription>
        </CardHeader>
        <CardContent className="grid gap-3">
          <Label htmlFor="words" className="sr-only">
            Words
          </Label>
          <Textarea
            id="words"
            rows={4}
            placeholder="crane, plant, cloud…"
            value={viewState.words}
            onChange={(e) => actions.setWords(e.target.value)}
          />
          <div className="flex flex-wrap items-center justify-between gap-3">
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" aria-label="Approve right away" checked={viewState.approveOnAdd} onChange={(e) => actions.setApproveOnAdd(e.target.checked)} />
              Approve right away
            </label>
            <Button disabled={pending.add} onClick={actions.add}>
              {pending.add ? "Adding…" : "Add words"}
            </Button>
          </div>
          {viewState.lastResult && viewState.lastResult.errors.length > 0 ? (
            <ul className="text-destructive list-disc ps-5 text-sm">
              {viewState.lastResult.errors.map((e) => (
                <li key={e}>{e}</li>
              ))}
            </ul>
          ) : null}
        </CardContent>
      </Card>

      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 className="text-lg font-semibold">Answers</h2>
        <StatusFilter value={viewState.status} onChange={actions.setStatus} />
      </div>

      {viewState.isLoading ? (
        <p className="text-muted-foreground text-sm">Loading…</p>
      ) : viewState.errorMessage ? (
        <p className="text-destructive text-sm">{viewState.errorMessage}</p>
      ) : viewState.items.length === 0 ? (
        <p className="text-muted-foreground text-sm">Nothing here yet.</p>
      ) : (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full min-w-[480px] text-left text-sm">
            <thead className="bg-muted/50 border-b">
              <tr>
                <th className="px-3 py-2 font-medium">Word</th>
                <th className="px-3 py-2 font-medium">Status</th>
                <th className="px-3 py-2 font-medium">Added</th>
                <th className="px-3 py-2 text-end font-medium">Review</th>
              </tr>
            </thead>
            <tbody>
              {viewState.items.map((item) => (
                <tr key={item.id} className="border-b last:border-0">
                  <td className="px-3 py-2 font-mono font-semibold tracking-widest">{item.contentKey.toUpperCase()}</td>
                  <td className="px-3 py-2">
                    <StatusBadge status={item.status} />
                  </td>
                  <td className="text-muted-foreground px-3 py-2">{new Date(item.createdAt).toLocaleDateString()}</td>
                  <td className="px-3 py-2">
                    <ReviewActions
                      status={item.status}
                      disabled={pending.status}
                      onApprove={() => actions.approve(item.id)}
                      onRetire={() => actions.retire(item.id)}
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
