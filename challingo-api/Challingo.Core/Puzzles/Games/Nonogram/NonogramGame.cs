namespace Challingo.Core.Puzzles.Games.Nonogram;

/// <summary>
/// Fill cells so each row and column matches its run-length clues. Generated with a unique solution.
/// Public: <c>{width, height, rows:[[…]], cols:[[…]]}</c>; submission: <c>{cells:[0|1…]}</c> row-major.
/// Any grid matching every clue is accepted (it can only be the solution).
/// </summary>
public sealed class NonogramGame : IPuzzleGame
{
    private const int MaxTries = 3000;

    public string Key => "nonogram";
    public int GeneratorVersion => 1;

    public ValueTask<GeneratedPuzzle> GenerateAsync(int seed, int difficulty, CancellationToken ct = default)
    {
        var size = difficulty switch { <= 1 => 5, 2 => 8, 3 => 10, _ => 12 };
        var rng = new Random(seed);
        for (var attempt = 0; attempt < MaxTries; attempt++)
        {
            var cells = new int[size * size];
            for (var i = 0; i < cells.Length; i++)
                cells[i] = rng.NextDouble() < 0.6 ? 1 : 0;

            var rows = Enumerable.Range(0, size).Select(r => Clue(Line(cells, size, r, true))).ToArray();
            var cols = Enumerable.Range(0, size).Select(c => Clue(Line(cells, size, c, false))).ToArray();
            if (NonogramSolver.CountSolutions(size, size, rows, cols, 2) != 1)
                continue;

            return ValueTask.FromResult(new GeneratedPuzzle(
                PuzzleJson.Write(new Public(size, size, rows, cols)),
                PuzzleJson.Write(new Secret(cells))));
        }
        throw new InvalidOperationException("Could not generate a unique nonogram.");
    }

    public PuzzleVerdict Verify(PuzzleSubmission submission)
    {
        var puzzle = PuzzleJson.Read<Public>(submission.PublicJson);
        var cells = PuzzleJson.TryRead<Submission>(submission.SubmissionJson)?.Cells;
        if (cells is null || cells.Length != puzzle.Width * puzzle.Height || cells.Any(v => v is not (0 or 1)))
            return PuzzleVerdict.Invalid($"Expected {puzzle.Width * puzzle.Height} cells of 0 or 1.");

        for (var r = 0; r < puzzle.Height; r++)
            if (!Clue(Line(cells, puzzle.Width, r, true)).SequenceEqual(puzzle.Rows[r]))
                return PuzzleVerdict.Incorrect("A row doesn't match its clue.");
        for (var c = 0; c < puzzle.Width; c++)
            if (!Clue(Line(cells, puzzle.Width, c, false)).SequenceEqual(puzzle.Cols[c]))
                return PuzzleVerdict.Incorrect("A column doesn't match its clue.");
        return PuzzleVerdict.Solved();
    }

    private static int[] Line(int[] cells, int width, int k, bool row) =>
        row ? cells.Skip(k * width).Take(width).ToArray()
            : Enumerable.Range(0, cells.Length / width).Select(r => cells[r * width + k]).ToArray();

    /// <summary>Run lengths of filled cells; an empty line has the clue <c>[0]</c>.</summary>
    public static int[] Clue(int[] line)
    {
        var runs = new List<int>();
        var run = 0;
        foreach (var v in line)
        {
            if (v == 1)
            {
                run++;
            }
            else if (run > 0)
            {
                runs.Add(run);
                run = 0;
            }
        }
        if (run > 0)
            runs.Add(run);
        return runs.Count == 0 ? [0] : runs.ToArray();
    }

    private sealed record Public(int Width, int Height, int[][] Rows, int[][] Cols);
    private sealed record Secret(int[] Cells);
    private sealed record Submission(int[]? Cells);
}

/// <summary>Line-by-line propagation plus branching; counts solutions up to a limit.</summary>
internal static class NonogramSolver
{
    private const int Unknown = -1;

    public static int CountSolutions(int width, int height, int[][] rows, int[][] cols, int limit)
    {
        var grid = Enumerable.Repeat(Unknown, width * height).ToArray();
        var count = 0;
        Search(grid);
        return count;

        void Search(int[] g)
        {
            if (count >= limit || !Propagate(g, width, height, rows, cols))
                return;
            var cell = Array.IndexOf(g, Unknown);
            if (cell < 0)
            {
                count++;
                return;
            }
            foreach (var value in new[] { 1, 0 })
            {
                var copy = (int[])g.Clone();
                copy[cell] = value;
                Search(copy);
                if (count >= limit)
                    return;
            }
        }
    }

    /// <summary>Repeats line solving until nothing changes; false on contradiction.</summary>
    private static bool Propagate(int[] g, int width, int height, int[][] rows, int[][] cols)
    {
        bool changed;
        do
        {
            changed = false;
            for (var r = 0; r < height; r++)
            {
                var line = Enumerable.Range(0, width).Select(c => g[r * width + c]).ToArray();
                var solved = SolveLine(line, rows[r]);
                if (solved is null)
                    return false;
                for (var c = 0; c < width; c++)
                    if (g[r * width + c] != solved[c]) { g[r * width + c] = solved[c]; changed = true; }
            }
            for (var c = 0; c < width; c++)
            {
                var line = Enumerable.Range(0, height).Select(r => g[r * width + c]).ToArray();
                var solved = SolveLine(line, cols[c]);
                if (solved is null)
                    return false;
                for (var r = 0; r < height; r++)
                    if (g[r * width + c] != solved[r]) { g[r * width + c] = solved[r]; changed = true; }
            }
        }
        while (changed);
        return true;
    }

    /// <summary>
    /// Cells forced in every placement of the clue that fits the known cells (Unknown where placements
    /// disagree); null when no placement fits.
    /// </summary>
    private static int[]? SolveLine(int[] line, int[] clue)
    {
        var blocks = clue.Length == 1 && clue[0] == 0 ? [] : clue;
        int n = line.Length;
        int[]? forced = null;
        var current = new int[n];

        void Place(int block, int start)
        {
            if (block == blocks.Length)
            {
                for (var i = start; i < n; i++)
                    if (line[i] == 1) return;
                for (var i = start; i < n; i++) current[i] = 0;
                Merge();
                return;
            }
            var remaining = blocks.Skip(block).Sum() + (blocks.Length - block - 1);
            for (var pos = start; pos + remaining <= n; pos++)
            {
                // Cells before the block are empty.
                var ok = true;
                for (var i = start; i < pos && ok; i++) ok = line[i] != 1;
                if (!ok) break;
                for (var i = pos; i < pos + blocks[block] && ok; i++) ok = line[i] != 0;
                var end = pos + blocks[block];
                if (ok && end < n) ok = line[end] != 1;
                if (!ok) continue;

                for (var i = start; i < pos; i++) current[i] = 0;
                for (var i = pos; i < end; i++) current[i] = 1;
                if (end < n) current[end] = 0;
                Place(block + 1, Math.Min(n, end + 1));
            }
        }

        void Merge()
        {
            if (forced is null)
            {
                forced = (int[])current.Clone();
                return;
            }
            for (var i = 0; i < n; i++)
                if (forced[i] != current[i]) forced[i] = Unknown;
        }

        Place(0, 0);
        return forced;
    }
}
