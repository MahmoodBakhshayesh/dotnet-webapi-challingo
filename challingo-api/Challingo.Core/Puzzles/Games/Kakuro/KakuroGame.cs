using System.Numerics;

namespace Challingo.Core.Puzzles.Games.Kakuro;

/// <summary>
/// Fill white cells with 1–9 so each across/down run adds up to its clue with no repeated digit.
/// Generated with a unique solution. Public: <c>{size, grid:[{t:"b"|"c"|"w", a?, d?}]}</c> row-major
/// (b = block, c = clue cell with across/down sums, w = white); submission: <c>{cells:[…]}</c>, 0 outside white cells.
/// </summary>
public sealed class KakuroGame : IPuzzleGame
{
    private const int MaxLayouts = 200;
    private const int MaxRepairs = 300;

    public string Key => "kakuro";
    public int GeneratorVersion => 1;

    public ValueTask<GeneratedPuzzle> GenerateAsync(int seed, int difficulty, CancellationToken ct = default)
    {
        var size = difficulty switch { <= 1 => 6, 2 => 7, 3 => 8, _ => 9 };
        var rng = new Random(seed);
        for (var layoutTry = 0; layoutTry < MaxLayouts; layoutTry++)
        {
            var white = RandomLayout(size, rng);
            if (white is null || !Connected(size, white))
                continue;
            var runs = KakuroRuns.Find(size, white);
            var solution = KakuroSolver.Fill(size, white, runs, rng);
            if (solution is null)
                continue;

            // Repair towards uniqueness: while another solution exists, change a digit where the two differ.
            for (var repair = 0; repair < MaxRepairs; repair++)
            {
                var sums = runs.Select(r => r.Cells.Sum(i => solution[i])).ToArray();
                var other = KakuroSolver.FindAlternative(size, white, runs, sums, solution);
                if (other is null)
                    return ValueTask.FromResult(Build(size, white, runs, sums, solution));

                var differing = Enumerable.Range(0, solution.Length).Where(i => white[i] && other[i] != solution[i]).ToList();
                var cell = differing[rng.Next(differing.Count)];
                var choices = KakuroSolver.FreeDigits(size, runs, solution, cell).Where(d => d != solution[cell]).ToList();
                if (choices.Count > 0)
                    solution[cell] = choices[rng.Next(choices.Count)];
            }
        }
        throw new InvalidOperationException("Could not generate a unique Kakuro.");
    }

    private static bool Connected(int size, bool[] white)
    {
        var cells = Enumerable.Range(0, white.Length).Where(i => white[i]).ToList();
        var seen = new HashSet<int> { cells[0] };
        var queue = new Queue<int>(seen);
        while (queue.Count > 0)
        {
            var i = queue.Dequeue();
            foreach (var n in new[] { i - size, i + size, i % size > 0 ? i - 1 : -1, i % size < size - 1 ? i + 1 : -1 })
                if (n >= 0 && n < white.Length && white[n] && seen.Add(n))
                    queue.Enqueue(n);
        }
        return seen.Count == cells.Count;
    }

    public PuzzleVerdict Verify(PuzzleSubmission submission)
    {
        var puzzle = PuzzleJson.Read<Public>(submission.PublicJson);
        var solution = PuzzleJson.Read<Secret>(submission.SecretJson).Solution;
        var cells = PuzzleJson.TryRead<Submission>(submission.SubmissionJson)?.Cells;
        if (cells is null || cells.Length != solution.Length)
            return PuzzleVerdict.Invalid($"Expected {solution.Length} cells.");

        for (var i = 0; i < cells.Length; i++)
        {
            var isWhite = puzzle.Grid[i].T == "w";
            if (!isWhite && cells[i] != 0)
                return PuzzleVerdict.Invalid("Only white cells take digits.");
            if (isWhite && (cells[i] < 1 || cells[i] > 9))
                return PuzzleVerdict.Incorrect("Fill every white cell with 1–9.");
        }
        // Unique solution: a correct grid equals it.
        return cells.AsSpan().SequenceEqual(solution)
            ? PuzzleVerdict.Solved()
            : PuzzleVerdict.Incorrect("Some sums don't add up.");
    }

    /// <summary>
    /// Random symmetric layout: every white cell sits in an across and a down run of 2 to <c>maxRun</c> cells.
    /// Short runs are what make a unique solution likely.
    /// </summary>
    private static bool[]? RandomLayout(int size, Random rng)
    {
        var maxRun = size <= 7 ? 4 : 5;
        var white = new bool[size * size];
        for (var r = 1; r < size; r++)
        for (var c = 1; c < size; c++)
            white[r * size + c] = true;

        bool Block(int r, int c)
        {
            if (!white[r * size + c])
                return false;
            white[r * size + c] = false;
            // 180° symmetry around the white area's centre.
            white[(size - r) * size + (size - c)] = false;
            return true;
        }

        for (var k = (size - 1) * (size - 1) / 8; k > 0; k--)
            Block(rng.Next(1, size), rng.Next(1, size));

        bool changed;
        do
        {
            changed = false;
            // Cut runs longer than maxRun at a random point that leaves both sides at least 2 long.
            foreach (var across in new[] { true, false })
            for (var line = 1; line < size; line++)
            {
                var start = 1;
                while (start < size)
                {
                    int Cell(int k) => across ? line * size + k : k * size + line;
                    if (!white[Cell(start)]) { start++; continue; }
                    var end = start;
                    while (end + 1 < size && white[Cell(end + 1)]) end++;
                    var length = end - start + 1;
                    if (length > maxRun)
                    {
                        var cut = start + rng.Next(2, length - 2);
                        changed |= across ? Block(line, cut) : Block(cut, line);
                    }
                    start = end + 1;
                }
            }

            // A white cell alone in a row or column run becomes a block.
            for (var r = 1; r < size; r++)
            for (var c = 1; c < size; c++)
            {
                if (!white[r * size + c])
                    continue;
                var acrossOk = (c > 1 && white[r * size + c - 1]) || (c < size - 1 && white[r * size + c + 1]);
                var downOk = (r > 1 && white[(r - 1) * size + c]) || (r < size - 1 && white[(r + 1) * size + c]);
                if (!acrossOk || !downOk)
                    changed |= Block(r, c);
            }
        }
        while (changed);

        var whiteCount = white.Count(w => w);
        return whiteCount >= (size - 1) * (size - 1) * 2 / 5 ? white : null;
    }

    private static GeneratedPuzzle Build(int size, bool[] white, IReadOnlyList<KakuroRun> runs, int[] sums, int[] solution)
    {
        var grid = new Entry[size * size];
        for (var i = 0; i < grid.Length; i++)
            grid[i] = white[i] ? new Entry("w", null, null) : new Entry("b", null, null);
        for (var k = 0; k < runs.Count; k++)
        {
            var clue = runs[k].ClueCell;
            var existing = grid[clue];
            grid[clue] = runs[k].Across
                ? new Entry("c", sums[k], existing.D)
                : new Entry("c", existing.A, sums[k]);
        }
        return new GeneratedPuzzle(
            PuzzleJson.Write(new Public(size, grid)),
            PuzzleJson.Write(new Secret(solution)));
    }

    private sealed record Entry(string T, int? A, int? D);
    private sealed record Public(int Size, Entry[] Grid);
    private sealed record Secret(int[] Solution);
    private sealed record Submission(int[]? Cells);
}

internal sealed record KakuroRun(int ClueCell, bool Across, int[] Cells);

internal static class KakuroRuns
{
    public static List<KakuroRun> Find(int size, bool[] white)
    {
        var runs = new List<KakuroRun>();
        for (var r = 0; r < size; r++)
        for (var c = 0; c < size; c++)
        {
            var i = r * size + c;
            if (white[i])
                continue;
            if (c + 1 < size && white[i + 1])
            {
                var cells = new List<int>();
                for (var cc = c + 1; cc < size && white[r * size + cc]; cc++)
                    cells.Add(r * size + cc);
                runs.Add(new KakuroRun(i, true, cells.ToArray()));
            }
            if (r + 1 < size && white[i + size])
            {
                var cells = new List<int>();
                for (var rr = r + 1; rr < size && white[rr * size + c]; rr++)
                    cells.Add(rr * size + c);
                runs.Add(new KakuroRun(i, false, cells.ToArray()));
            }
        }
        return runs;
    }
}

internal static class KakuroSolver
{
    private const int AllDigits = 0b1_1111_1111;

    /// <summary>Digit sets (bit d-1 = digit d) of each length that add up to each sum.</summary>
    private static readonly Dictionary<(int Length, int Sum), int[]> Combos = BuildCombos();

    private static Dictionary<(int, int), int[]> BuildCombos()
    {
        var map = new Dictionary<(int, int), List<int>>();
        for (var mask = 1; mask <= AllDigits; mask++)
        {
            int length = BitOperations.PopCount((uint)mask), sum = 0;
            for (var d = 1; d <= 9; d++)
                if ((mask & (1 << (d - 1))) != 0) sum += d;
            if (!map.TryGetValue((length, sum), out var list))
                map[(length, sum)] = list = [];
            list.Add(mask);
        }
        return map.ToDictionary(kv => kv.Key, kv => kv.Value.ToArray());
    }

    /// <summary>A random valid digit fill (no repeats within runs); null if none was found quickly.</summary>
    public static int[]? Fill(int size, bool[] white, List<KakuroRun> runs, Random rng)
    {
        var values = new int[size * size];
        var (across, down) = RunIndex(size, runs);
        var order = Enumerable.Range(0, values.Length).Where(i => white[i]).ToArray();
        var budget = 20_000;

        bool Step(int k)
        {
            if (k == order.Length)
                return true;
            if (--budget < 0)
                return false;
            var cell = order[k];
            var used = UsedMask(values, runs[across[cell]]) | UsedMask(values, runs[down[cell]]);
            var digits = Enumerable.Range(1, 9).Where(d => (used & (1 << (d - 1))) == 0).ToList();
            rng.Shuffle(digits);
            foreach (var d in digits)
            {
                values[cell] = d;
                if (Step(k + 1))
                    return true;
            }
            values[cell] = 0;
            return false;
        }

        return Step(0) ? values : null;
    }

    /// <summary>Digits a cell could take without repeating within its across and down runs (its own value excluded).</summary>
    public static IEnumerable<int> FreeDigits(int size, List<KakuroRun> runs, int[] values, int cell)
    {
        var used = 0;
        foreach (var run in runs.Where(r => r.Cells.Contains(cell)))
            foreach (var i in run.Cells)
                if (i != cell && values[i] != 0) used |= 1 << (values[i] - 1);
        return Enumerable.Range(1, 9).Where(d => (used & (1 << (d - 1))) == 0);
    }

    /// <summary>A solution of the clues other than <paramref name="known"/>, or null when <paramref name="known"/> is the only one.</summary>
    public static int[]? FindAlternative(int size, bool[] white, List<KakuroRun> runs, int[] sums, int[] known)
    {
        int[]? found = null;
        Solve(size, white, runs, sums, values =>
        {
            if (!values.AsSpan().SequenceEqual(known))
            {
                found = (int[])values.Clone();
                return true;
            }
            return false;
        });
        return found;
    }

    public static int CountSolutions(int size, bool[] white, List<KakuroRun> runs, int[] sums, int limit)
    {
        var count = 0;
        Solve(size, white, runs, sums, _ => ++count >= limit);
        return count;
    }

    /// <summary>Depth-first search over all solutions; <paramref name="onSolution"/> returns true to stop.</summary>
    private static void Solve(int size, bool[] white, List<KakuroRun> runs, int[] sums, Func<int[], bool> onSolution)
    {
        var values = new int[size * size];
        var (across, down) = RunIndex(size, runs);
        var cells = Enumerable.Range(0, values.Length).Where(i => white[i]).ToArray();
        var stop = false;
        Search();

        void Search()
        {
            // Most constrained empty cell first.
            int best = -1, bestMask = 0, bestCount = 10;
            foreach (var cell in cells)
            {
                if (values[cell] != 0)
                    continue;
                var mask = Candidates(cell, across[cell]) & Candidates(cell, down[cell]);
                var n = BitOperations.PopCount((uint)mask);
                if (n == 0)
                    return;
                if (n < bestCount)
                {
                    (best, bestMask, bestCount) = (cell, mask, n);
                    if (n == 1)
                        break;
                }
            }
            if (best < 0)
            {
                stop = onSolution(values);
                return;
            }
            for (var d = 1; d <= 9 && !stop; d++)
            {
                if ((bestMask & (1 << (d - 1))) == 0)
                    continue;
                values[best] = d;
                Search();
            }
            values[best] = 0;
        }

        int Candidates(int cell, int runIndex)
        {
            var run = runs[runIndex];
            var placed = UsedMask(values, run);
            var mask = 0;
            if (Combos.TryGetValue((run.Cells.Length, sums[runIndex]), out var combos))
            {
                foreach (var combo in combos)
                {
                    if ((combo & placed) == placed)
                        mask |= combo & ~placed;
                }
            }
            return mask;
        }
    }

    private static int UsedMask(int[] values, KakuroRun run)
    {
        var mask = 0;
        foreach (var i in run.Cells)
            if (values[i] != 0) mask |= 1 << (values[i] - 1);
        return mask;
    }

    private static (int[] Across, int[] Down) RunIndex(int size, List<KakuroRun> runs)
    {
        var across = new int[size * size];
        var down = new int[size * size];
        for (var k = 0; k < runs.Count; k++)
        foreach (var cell in runs[k].Cells)
        {
            if (runs[k].Across) across[cell] = k;
            else down[cell] = k;
        }
        return (across, down);
    }
}
