namespace Challingo.Core.Puzzles.Games.MineLogic;

/// <summary>
/// Minesweeper on a board generated to be solvable by logic alone from the given opening — never a guess.
/// The mines stay on the server; each reveal is a move. Public: <c>{width, height, mines, opening:[{i,n}]}</c>;
/// move: <c>{reveal: cellIndex}</c>. Revealing a mine ends the attempt.
/// </summary>
public sealed class MineLogicGame : IInteractivePuzzleGame
{
    private const int MaxTries = 2000;

    public string Key => "mine-logic";
    public int GeneratorVersion => 1;

    public ValueTask<GeneratedPuzzle> GenerateAsync(int seed, int difficulty, CancellationToken ct = default)
    {
        var (width, height, mines) = difficulty switch
        {
            <= 1 => (8, 8, 10),
            2 => (9, 9, 13),
            3 => (10, 10, 18),
            _ => (10, 12, 24),
        };
        var rng = new Random(seed);
        for (var attempt = 0; attempt < MaxTries; attempt++)
        {
            var board = new Board(width, height);
            var start = board.Index(rng.Next(1, height - 1), rng.Next(1, width - 1));
            var forbidden = board.Neighbours(start).Append(start).ToHashSet();
            var candidates = Enumerable.Range(0, board.Cells).Where(i => !forbidden.Contains(i)).ToList();
            rng.Shuffle(candidates);
            var mineSet = candidates.Take(mines).ToHashSet();
            var numbers = board.Numbers(mineSet);

            var opening = board.Flood(start, mineSet, numbers, []);
            if (!MineLogicSolver.SolvesWithoutGuessing(board, mineSet, numbers, opening))
                continue;

            return ValueTask.FromResult(new GeneratedPuzzle(
                PuzzleJson.Write(new Public(width, height, mines, opening.Order().Select(i => new Cell(i, numbers[i])).ToArray())),
                PuzzleJson.Write(new Secret(mineSet.Order().ToArray()))));
        }
        throw new InvalidOperationException("Could not generate a no-guess Mine Logic board.");
    }

    public PuzzleMoveResult ApplyMove(PuzzleMove move)
    {
        var puzzle = PuzzleJson.Read<Public>(move.PublicJson);
        var mines = PuzzleJson.Read<Secret>(move.SecretJson).Mines.ToHashSet();
        var board = new Board(puzzle.Width, puzzle.Height);
        var revealed = move.StateJson is null
            ? puzzle.Opening.Select(c => c.I).ToHashSet()
            : PuzzleJson.Read<State>(move.StateJson).Revealed.Select(c => c.I).ToHashSet();

        var reveal = PuzzleJson.TryRead<Move>(move.MoveJson)?.Reveal;
        if (reveal is not { } cell || cell < 0 || cell >= board.Cells)
            return PuzzleMoveResult.Invalid("A move is {\"reveal\": cellIndex}.");
        if (revealed.Contains(cell))
            return PuzzleMoveResult.Invalid("That cell is already revealed.");

        var numbers = board.Numbers(mines);
        State StateOf(IEnumerable<int> cells) => new(cells.Order().Select(i => new Cell(i, numbers[i])).ToArray());

        if (mines.Contains(cell))
        {
            return new PuzzleMoveResult(
                PuzzleJson.Write(StateOf(revealed)),
                PuzzleJson.Write(new { mine = true, mines = mines.Order() }),
                PuzzleOutcome.Failed,
                PuzzleJson.Write(new { revealed = revealed.Count, hitMine = true }));
        }

        var opened = board.Flood(cell, mines, numbers, revealed);
        revealed.UnionWith(opened);
        var solved = revealed.Count == board.Cells - mines.Count;

        return new PuzzleMoveResult(
            PuzzleJson.Write(StateOf(revealed)),
            PuzzleJson.Write(new { mine = false, revealed = opened.Order().Select(i => new Cell(i, numbers[i])) }),
            solved ? PuzzleOutcome.Solved : null,
            solved ? PuzzleJson.Write(new { revealed = revealed.Count, hitMine = false }) : null);
    }

    public PuzzleVerdict Verify(PuzzleSubmission submission) =>
        PuzzleVerdict.Incorrect("Reveal every safe cell to finish.");

    private sealed record Public(int Width, int Height, int Mines, Cell[] Opening);
    private sealed record Cell(int I, int N);
    private sealed record Secret(int[] Mines);
    private sealed record Move(int? Reveal);
    /// <summary>Revealed cells with their numbers, so a resumed game can redraw the board.</summary>
    private sealed record State(Cell[] Revealed);
}

internal sealed class Board(int width, int height)
{
    public int Width { get; } = width;
    public int Height { get; } = height;
    public int Cells => Width * Height;

    public int Index(int row, int col) => row * Width + col;

    public IEnumerable<int> Neighbours(int i)
    {
        int r = i / Width, c = i % Width;
        for (var dr = -1; dr <= 1; dr++)
        for (var dc = -1; dc <= 1; dc++)
        {
            if (dr == 0 && dc == 0)
                continue;
            int nr = r + dr, nc = c + dc;
            if (nr >= 0 && nr < Height && nc >= 0 && nc < Width)
                yield return Index(nr, nc);
        }
    }

    public int[] Numbers(HashSet<int> mines)
    {
        var numbers = new int[Cells];
        for (var i = 0; i < Cells; i++)
            numbers[i] = mines.Contains(i) ? -1 : Neighbours(i).Count(mines.Contains);
        return numbers;
    }

    /// <summary>Cells opened by revealing <paramref name="start"/>: zeros spread to their neighbours.</summary>
    public HashSet<int> Flood(int start, HashSet<int> mines, int[] numbers, HashSet<int> alreadyRevealed)
    {
        var opened = new HashSet<int>();
        var queue = new Queue<int>();
        queue.Enqueue(start);
        while (queue.Count > 0)
        {
            var i = queue.Dequeue();
            if (mines.Contains(i) || alreadyRevealed.Contains(i) || !opened.Add(i))
                continue;
            if (numbers[i] == 0)
            {
                foreach (var n in Neighbours(i))
                    queue.Enqueue(n);
            }
        }
        return opened;
    }
}

/// <summary>Deterministic-deduction solver: single-cell rules plus the subset rule between pairs of clues.</summary>
internal static class MineLogicSolver
{
    public static bool SolvesWithoutGuessing(Board board, HashSet<int> mines, int[] numbers, HashSet<int> opening)
    {
        var revealed = new HashSet<int>(opening);
        var flagged = new HashSet<int>();
        var safeTotal = board.Cells - mines.Count;

        bool progress;
        do
        {
            progress = false;
            var constraints = new List<(HashSet<int> Unknown, int Mines)>();
            foreach (var i in revealed)
            {
                var unknown = board.Neighbours(i).Where(n => !revealed.Contains(n) && !flagged.Contains(n)).ToHashSet();
                if (unknown.Count == 0)
                    continue;
                var remaining = numbers[i] - board.Neighbours(i).Count(flagged.Contains);
                constraints.Add((unknown, remaining));
            }

            void Reveal(int cell)
            {
                if (revealed.Contains(cell))
                    return;
                revealed.UnionWith(board.Flood(cell, mines, numbers, revealed));
                progress = true;
            }

            void Flag(int cell)
            {
                if (flagged.Add(cell))
                    progress = true;
            }

            foreach (var (unknown, remaining) in constraints)
            {
                if (remaining == 0)
                    foreach (var cell in unknown) Reveal(cell);
                else if (remaining == unknown.Count)
                    foreach (var cell in unknown) Flag(cell);
            }

            if (!progress)
            {
                // Subset rule: if A's unknowns ⊆ B's, the difference holds exactly (B − A) mines.
                foreach (var a in constraints)
                foreach (var b in constraints)
                {
                    if (ReferenceEquals(a.Unknown, b.Unknown) || a.Unknown.Count >= b.Unknown.Count || !a.Unknown.IsSubsetOf(b.Unknown))
                        continue;
                    var diff = b.Unknown.Except(a.Unknown).ToList();
                    var diffMines = b.Mines - a.Mines;
                    if (diffMines == 0)
                        foreach (var cell in diff) Reveal(cell);
                    else if (diffMines == diff.Count)
                        foreach (var cell in diff) Flag(cell);
                }
            }

            // A wrong deduction would mean a bug; treat it as "not solvable" rather than trusting it.
            if (revealed.Overlaps(mines))
                return false;
        }
        while (progress && revealed.Count < safeTotal);

        return revealed.Count == safeTotal;
    }
}
