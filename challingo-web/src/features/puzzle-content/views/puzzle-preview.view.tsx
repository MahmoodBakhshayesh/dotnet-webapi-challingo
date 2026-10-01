/** Presentational: reads only `viewState` + invokes `actions`. */
"use client";

import { Eye } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import type { PuzzlePreviewViewModel } from "@/features/puzzle-content/controllers/puzzle-preview.controller";
import { GAME_TITLES } from "@/features/puzzle-content/lib/crossword-layout";
import { selectClass } from "@/features/puzzle-content/views/content-ui";
import { PuzzleRenderer } from "@/features/puzzle-content/views/puzzle-renderer";

export function PuzzlePreviewView({ viewState, actions, pending }: PuzzlePreviewViewModel) {
  const preview = viewState.preview;
  return (
    <div className="space-y-6">
      <div className="flex items-start gap-3">
        <Eye className="mt-1 size-6 opacity-80" />
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Puzzle preview</h1>
          <p className="text-muted-foreground text-sm">Generate any game at any difficulty, solution included. Nothing is stored or shown to players.</p>
        </div>
      </div>

      <Card>
        <CardContent className="flex flex-wrap items-end gap-3 pt-6">
          <label className="grid gap-1 text-sm">
            Game
            <select className={selectClass} value={viewState.gameKey} onChange={(e) => actions.setGameKey(e.target.value)}>
              {(viewState.games.length ? viewState.games : Object.keys(GAME_TITLES)).map((g) => (
                <option key={g} value={g}>
                  {GAME_TITLES[g] ?? g}
                </option>
              ))}
            </select>
          </label>
          <label className="grid gap-1 text-sm">
            Difficulty
            <select className={selectClass} value={viewState.difficulty} onChange={(e) => actions.setDifficulty(Number(e.target.value))}>
              {[1, 2, 3, 4].map((d) => (
                <option key={d} value={d}>
                  {d}
                </option>
              ))}
            </select>
          </label>
          <label className="grid gap-1 text-sm">
            Seed (optional)
            <Input className="w-40" inputMode="numeric" placeholder="random" value={viewState.seed} onChange={(e) => actions.setSeed(e.target.value)} />
          </label>
          <Button disabled={pending.generate} onClick={actions.generate}>
            {pending.generate ? "Generating…" : "Generate"}
          </Button>
        </CardContent>
      </Card>

      {preview ? (
        <Card>
          <CardHeader>
            <CardTitle>
              {GAME_TITLES[preview.gameKey] ?? preview.gameKey} · difficulty {preview.difficulty}
            </CardTitle>
            <CardDescription>
              Seed {preview.seed}. The same seed and difficulty always produce this puzzle.
            </CardDescription>
          </CardHeader>
          <CardContent className="grid gap-4">
            <PuzzleRenderer gameKey={preview.gameKey} puzzle={preview.puzzle} secret={preview.secret} />
            <details className="text-sm">
              <summary className="cursor-pointer font-medium">Raw JSON</summary>
              <pre className="bg-muted mt-2 max-h-96 overflow-auto rounded-md p-3 text-xs">
                {JSON.stringify({ puzzle: preview.puzzle, secret: preview.secret }, null, 2)}
              </pre>
            </details>
          </CardContent>
        </Card>
      ) : null}
    </div>
  );
}
