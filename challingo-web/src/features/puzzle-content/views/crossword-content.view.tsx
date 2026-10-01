/** Presentational: reads only `viewState` + invokes `actions`. */
"use client";

import { Grid3x3 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { CrosswordContentViewModel } from "@/features/puzzle-content/controllers/crossword-content.controller";
import { layoutCrossword, type CrosswordPayload } from "@/features/puzzle-content/lib/crossword-layout";
import { ReviewActions, StatusBadge, StatusFilter, selectClass } from "@/features/puzzle-content/views/content-ui";

const SIZES = [3, 4, 5, 6, 7];

export function CrosswordContentView({ viewState, actions, pending }: CrosswordContentViewModel) {
  const { width, height, cells, entries, numbers, clues } = viewState;
  return (
    <div className="space-y-6">
      <div className="flex items-start gap-3">
        <Grid3x3 className="mt-1 size-6 opacity-80" />
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Mini Crosswords</h1>
          <p className="text-muted-foreground text-sm">Build a grid, write a clue for every entry, then approve it for play.</p>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>New crossword</CardTitle>
          <CardDescription>
            Type a letter in each square. Type <kbd className="rounded border px-1">.</kbd> or double-click a square to make it a black block.
          </CardDescription>
        </CardHeader>
        <CardContent className="grid gap-6 lg:grid-cols-[auto_1fr]">
          <div className="space-y-3">
            <div className="flex gap-3">
              <label className="grid gap-1 text-sm">
                Width
                <select className={selectClass} value={width} onChange={(e) => actions.resize(Number(e.target.value), height)}>
                  {SIZES.map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </select>
              </label>
              <label className="grid gap-1 text-sm">
                Height
                <select className={selectClass} value={height} onChange={(e) => actions.resize(width, Number(e.target.value))}>
                  {SIZES.map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </select>
              </label>
            </div>
            <div
              className="border-foreground inline-grid overflow-hidden rounded-lg border-2"
              style={{ gridTemplateColumns: `repeat(${width}, 3rem)` }}
            >
              {cells.map((value, i) =>
                value === "#" ? (
                  <button
                    key={i}
                    type="button"
                    aria-label={`Block at row ${Math.floor(i / width) + 1}, column ${(i % width) + 1}; click to clear`}
                    className="size-12 border border-neutral-700 bg-neutral-900"
                    onClick={() => actions.toggleBlock(i)}
                  />
                ) : (
                  <div key={i} className="relative size-12 border">
                    {numbers.get(i) ? (
                      <span className="pointer-events-none absolute start-1 top-0.5 text-[10px] font-bold">{numbers.get(i)}</span>
                    ) : null}
                    <input
                      aria-label={`Row ${Math.floor(i / width) + 1}, column ${(i % width) + 1}`}
                      className="focus:bg-primary/10 size-full bg-transparent text-center text-xl font-bold uppercase outline-none"
                      value={value}
                      maxLength={2}
                      onChange={(e) => actions.setCell(i, e.target.value)}
                      onDoubleClick={() => actions.toggleBlock(i)}
                    />
                  </div>
                ),
              )}
            </div>
          </div>

          <div className="grid content-start gap-4">
            {(["Across", "Down"] as const).map((dir) => (
              <div key={dir} className="grid gap-2">
                <h3 className="text-sm font-semibold">{dir}</h3>
                {entries
                  .filter((e) => e.across === (dir === "Across"))
                  .map((e) => {
                    const key = `${e.number}${e.across ? "A" : "D"}`;
                    const answer = e.cells.map((c) => cells[c] || "·").join("");
                    return (
                      <div key={key} className="grid grid-cols-[3.5rem_1fr] items-center gap-2">
                        <Label htmlFor={`clue-${key}`} className="font-mono text-xs">
                          {key} <span className="text-muted-foreground">{answer}</span>
                        </Label>
                        <Input id={`clue-${key}`} value={clues[key] ?? ""} maxLength={120} onChange={(ev) => actions.setClue(key, ev.target.value)} />
                      </div>
                    );
                  })}
              </div>
            ))}
            <div className="grid gap-1">
              <Label htmlFor="notes">Notes (optional)</Label>
              <Input id="notes" value={viewState.notes} onChange={(e) => actions.setNotes(e.target.value)} />
            </div>
            <div className="flex flex-wrap items-center justify-between gap-3">
              <label className="flex items-center gap-2 text-sm">
                <input type="checkbox" aria-label="Approve right away" checked={viewState.approve} onChange={(e) => actions.setApprove(e.target.checked)} />
                Approve right away
              </label>
              <Button disabled={pending.save || !viewState.canSave} onClick={actions.save}>
                {pending.save ? "Saving…" : "Save crossword"}
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 className="text-lg font-semibold">Crossword bank</h2>
        <StatusFilter value={viewState.status} onChange={actions.setStatus} />
      </div>

      {viewState.isLoading ? (
        <p className="text-muted-foreground text-sm">Loading…</p>
      ) : viewState.errorMessage ? (
        <p className="text-destructive text-sm">{viewState.errorMessage}</p>
      ) : viewState.items.length === 0 ? (
        <p className="text-muted-foreground text-sm">Nothing here yet.</p>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {viewState.items.map((item) => {
            const payload = item.payload as CrosswordPayload;
            return (
              <Card key={item.id}>
                <CardHeader className="flex flex-row items-center justify-between">
                  <StatusBadge status={item.status} />
                  <span className="text-muted-foreground text-xs">{new Date(item.createdAt).toLocaleDateString()}</span>
                </CardHeader>
                <CardContent className="grid gap-3">
                  <MiniGrid payload={payload} />
                  <ClueList payload={payload} />
                  {item.notes ? <p className="text-muted-foreground text-xs">{item.notes}</p> : null}
                  <ReviewActions
                    status={item.status}
                    disabled={pending.status}
                    onApprove={() => actions.approveItem(item.id)}
                    onRetire={() => actions.retireItem(item.id)}
                  />
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}

function MiniGrid({ payload }: { payload: CrosswordPayload }) {
  const width = payload.rows[0]?.length ?? 0;
  const numbers = new Map(layoutCrossword(payload.rows).map((e) => [e.cells[0], e.number]));
  const letters = payload.rows.join("");
  return (
    <div className="border-foreground inline-grid w-fit overflow-hidden rounded-md border-2" style={{ gridTemplateColumns: `repeat(${width}, 2rem)` }}>
      {letters.split("").map((ch, i) =>
        ch === "#" ? (
          <div key={i} className="size-8 bg-neutral-900" />
        ) : (
          <div key={i} className="relative flex size-8 items-center justify-center border text-sm font-bold">
            {numbers.get(i) ? <span className="absolute start-0.5 top-0 text-[8px]">{numbers.get(i)}</span> : null}
            {ch}
          </div>
        ),
      )}
    </div>
  );
}

function ClueList({ payload }: { payload: CrosswordPayload }) {
  return (
    <div className="grid grid-cols-2 gap-2 text-xs">
      {(["across", "down"] as const).map((dir) => (
        <div key={dir}>
          <p className="font-semibold capitalize">{dir}</p>
          {Object.entries(payload.clues[dir]).map(([n, clue]) => (
            <p key={n}>
              <span className="font-bold">{n}</span> {clue}
            </p>
          ))}
        </div>
      ))}
    </div>
  );
}
