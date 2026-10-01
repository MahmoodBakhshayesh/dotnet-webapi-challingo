/**
 * Crossword numbering, identical to the API's CrosswordLayout: a white cell starts an entry when the
 * previous cell (left / above) is a block or the edge and the next one is white.
 */
export type CrosswordEntry = { number: number; cells: number[]; across: boolean };

export function layoutCrossword(rows: string[]): CrosswordEntry[] {
  const height = rows.length;
  const width = rows[0]?.length ?? 0;
  const white = (r: number, c: number) => r >= 0 && r < height && c >= 0 && c < width && rows[r][c] !== "#";
  const entries: CrosswordEntry[] = [];
  let number = 0;
  for (let r = 0; r < height; r++) {
    for (let c = 0; c < width; c++) {
      if (!white(r, c)) continue;
      const startsAcross = !white(r, c - 1) && white(r, c + 1);
      const startsDown = !white(r - 1, c) && white(r + 1, c);
      if (!startsAcross && !startsDown) continue;
      number++;
      if (startsAcross) {
        const cells: number[] = [];
        for (let cc = c; white(r, cc); cc++) cells.push(r * width + cc);
        entries.push({ number, cells, across: true });
      }
      if (startsDown) {
        const cells: number[] = [];
        for (let rr = r; white(rr, c); rr++) cells.push(rr * width + c);
        entries.push({ number, cells, across: false });
      }
    }
  }
  return entries;
}

export type CrosswordPayload = {
  rows: string[];
  clues: { across: Record<string, string>; down: Record<string, string> };
};

export const GAME_TITLES: Record<string, string> = {
  "word-hunt": "Word Hunt",
  "word-guess": "Word Guess",
  "mini-crossword": "Mini Crossword",
  "path-link": "Path Link",
  sudoku: "Sudoku",
  kakuro: "Kakuro",
  nonogram: "Nonogram",
  "mine-logic": "Mine Logic",
  "code-breaker": "Code Breaker",
  "number-merge": "Number Merge",
};
