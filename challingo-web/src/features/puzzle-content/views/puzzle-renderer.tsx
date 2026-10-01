/** Draws a generated puzzle with its solution, per game. Unknown shapes fall back to JSON. */
"use client";

import { cn } from "@/lib/utils";

type Json = Record<string, unknown>;
const nums = (v: unknown) => (Array.isArray(v) ? (v as number[]) : []);

const PALETTE = ["#5B47F5", "#FF6A55", "#E6A700", "#1F9D67", "#2F80ED", "#D94FAE", "#0E9F8F", "#8D5524"];

function Grid({ width, children }: { width: number; children: React.ReactNode }) {
  return (
    <div
      className="border-foreground inline-grid w-fit overflow-hidden rounded-md border-2"
      style={{ gridTemplateColumns: `repeat(${width}, 2.25rem)`, gridAutoRows: "2.25rem" }}
    >
      {children}
    </div>
  );
}

const box = "flex items-center justify-center border text-sm font-bold";

export function PuzzleRenderer({ gameKey, puzzle, secret }: { gameKey: string; puzzle: Json; secret: Json }) {
  switch (gameKey) {
    case "sudoku": {
      const size = puzzle.size as number;
      const givens = nums(puzzle.givens);
      const solution = nums(secret.solution);
      return (
        <Grid width={size}>
          {solution.map((v, i) => (
            <div key={i} className={cn(box, givens[i] ? "bg-muted" : "text-primary")}>
              {v}
            </div>
          ))}
        </Grid>
      );
    }
    case "kakuro": {
      const size = puzzle.size as number;
      const grid = puzzle.grid as { t: string; a?: number; d?: number }[];
      const solution = nums(secret.solution);
      return (
        <Grid width={size}>
          {grid.map((e, i) =>
            e.t === "w" ? (
              <div key={i} className={cn(box, "text-primary")}>
                {solution[i]}
              </div>
            ) : (
              <div key={i} className="relative border border-neutral-700 bg-neutral-900 text-[10px] font-bold text-white">
                {e.a ? <span className="absolute end-1 top-0.5">{e.a}</span> : null}
                {e.d ? <span className="absolute start-1 bottom-0.5">{e.d}</span> : null}
              </div>
            ),
          )}
        </Grid>
      );
    }
    case "nonogram": {
      const width = puzzle.width as number;
      return (
        <Grid width={width}>
          {nums(secret.cells).map((v, i) => (
            <div key={i} className={cn("border", v ? "bg-primary" : "bg-background")} />
          ))}
        </Grid>
      );
    }
    case "mine-logic": {
      const width = puzzle.width as number;
      const height = puzzle.height as number;
      const mines = new Set(nums(secret.mines));
      const opening = new Map((puzzle.opening as { i: number; n: number }[]).map((c) => [c.i, c.n]));
      return (
        <Grid width={width}>
          {Array.from({ length: width * height }, (_, i) => (
            <div key={i} className={cn(box, mines.has(i) ? "bg-destructive/15 text-destructive" : opening.has(i) ? "bg-background" : "bg-muted")}>
              {mines.has(i) ? "●" : opening.get(i) || ""}
            </div>
          ))}
        </Grid>
      );
    }
    case "path-link": {
      const size = puzzle.size as number;
      const owner = new Map<number, number>();
      (secret.paths as number[][]).forEach((p, k) => p.forEach((c) => owner.set(c, k)));
      const dots = new Set((puzzle.dots as number[][]).flat());
      return (
        <Grid width={size}>
          {Array.from({ length: size * size }, (_, i) => {
            const color = PALETTE[(owner.get(i) ?? 0) % PALETTE.length];
            return (
              <div key={i} className="flex items-center justify-center border" style={{ background: `${color}33` }}>
                {dots.has(i) ? <span className="size-5 rounded-full" style={{ background: color }} /> : null}
              </div>
            );
          })}
        </Grid>
      );
    }
    case "word-hunt": {
      const size = puzzle.size as number;
      const words = (secret.words as string[]) ?? [];
      return (
        <div className="grid gap-3">
          <Grid width={size}>
            {(puzzle.tiles as string[]).map((t, i) => (
              <div key={i} className={cn(box, "uppercase")}>
                {t === "qu" ? "Qu" : t}
              </div>
            ))}
          </Grid>
          <p className="text-sm">
            <span className="font-semibold">{words.length} words</span> · longest: {[...words].sort((a, b) => b.length - a.length).slice(0, 8).join(", ")}
          </p>
        </div>
      );
    }
    case "mini-crossword": {
      const width = puzzle.width as number;
      const blocks = new Set(nums(puzzle.blocks));
      const letters = String(secret.letters ?? "");
      return (
        <Grid width={width}>
          {letters.split("").map((ch, i) => (
            <div key={i} className={cn(box, blocks.has(i) && "bg-neutral-900")}>
              {blocks.has(i) ? "" : ch}
            </div>
          ))}
        </Grid>
      );
    }
    case "code-breaker":
      return (
        <div className="flex gap-2" aria-label="Secret code">
          {nums(secret.code).map((c, i) => (
            <span key={i} className="size-8 rounded-full" style={{ background: PALETTE[c % PALETTE.length] }} />
          ))}
        </div>
      );
    case "word-guess":
      return <p className="font-mono text-2xl font-bold tracking-[0.4em] uppercase">{String(secret.answer)}</p>;
    case "number-merge":
      return (
        <p className="text-sm">
          Reach <span className="font-bold">{String(puzzle.target)}</span> on a {String(puzzle.size)}×{String(puzzle.size)} board · shared
          tile seed {String(puzzle.seed)}
        </p>
      );
    default:
      return <pre className="bg-muted overflow-x-auto rounded-md p-3 text-xs">{JSON.stringify({ puzzle, secret }, null, 2)}</pre>;
  }
}
