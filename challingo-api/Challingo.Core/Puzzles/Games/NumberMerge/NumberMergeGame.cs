namespace Challingo.Core.Puzzles.Games.NumberMerge;

/// <summary>
/// Slide and merge tiles (2048 rules) until a tile reaches <c>target</c>; fewest moves wins. New tiles come
/// from a seed shared by every player in the round, so luck is identical. The app simulates locally and
/// submits its move string; the server replays it. Public: <c>{size, target, seed, rng:"mulberry32"}</c>;
/// submission: <c>{moves:"LURD…"}</c>.
/// Spawn rule (both sides): list empty cells row-major; index = next() % count; value = next() % 10 == 0 ? 4 : 2.
/// The game starts with two spawns. A move that changes nothing is ignored and not counted.
/// </summary>
public sealed class NumberMergeGame : IPuzzleGame
{
    private const int Size = 4;
    private const int MaxMoves = 10_000;

    public string Key => "number-merge";
    public int GeneratorVersion => 1;

    public ValueTask<GeneratedPuzzle> GenerateAsync(int seed, int difficulty, CancellationToken ct = default)
    {
        var target = difficulty switch { <= 1 => 128, 2 => 256, 3 => 512, _ => 1024 };
        var rngSeed = (uint)new Random(seed).NextInt64(0, uint.MaxValue + 1L);
        return ValueTask.FromResult(new GeneratedPuzzle(
            PuzzleJson.Write(new Public(Size, target, rngSeed, "mulberry32")),
            "{}"));
    }

    public PuzzleVerdict Verify(PuzzleSubmission submission)
    {
        var puzzle = PuzzleJson.Read<Public>(submission.PublicJson);
        var moves = PuzzleJson.TryRead<Submission>(submission.SubmissionJson)?.Moves;
        if (moves is null || moves.Length > MaxMoves || moves.Any(m => "LRUD".IndexOf(m) < 0))
            return PuzzleVerdict.Invalid("Submission is {\"moves\": \"LRUD…\"}.");

        var game = new MergeBoard(puzzle.Size, new Mulberry32(puzzle.Seed));
        var counted = 0;
        foreach (var direction in moves)
        {
            if (!game.Move(direction))
                continue;
            counted++;
            if (game.MaxTile >= puzzle.Target)
                return PuzzleVerdict.Solved(PuzzleJson.Write(new { moves = counted, maxTile = game.MaxTile }));
        }
        return PuzzleVerdict.Incorrect($"The {puzzle.Target} tile was not reached.");
    }

    private sealed record Public(int Size, int Target, uint Seed, string Rng);
    private sealed record Submission(string? Moves);
}

/// <summary>2048 board with deterministic spawns.</summary>
public sealed class MergeBoard
{
    private readonly int _size;
    private readonly Mulberry32 _rng;
    private readonly int[] _cells;

    public MergeBoard(int size, Mulberry32 rng)
    {
        _size = size;
        _rng = rng;
        _cells = new int[size * size];
        Spawn();
        Spawn();
    }

    public IReadOnlyList<int> Cells => _cells;
    public int MaxTile => _cells.Max();

    /// <summary>Applies L/R/U/D; returns false (and spawns nothing) when the board did not change.</summary>
    public bool Move(char direction)
    {
        var changed = false;
        for (var line = 0; line < _size; line++)
        {
            var indices = Line(direction, line);
            var values = indices.Select(i => _cells[i]).Where(v => v != 0).ToList();
            var merged = new List<int>(_size);
            for (var k = 0; k < values.Count; k++)
            {
                if (k + 1 < values.Count && values[k] == values[k + 1])
                {
                    merged.Add(values[k] * 2);
                    k++;
                }
                else
                {
                    merged.Add(values[k]);
                }
            }
            for (var k = 0; k < _size; k++)
            {
                var value = k < merged.Count ? merged[k] : 0;
                if (_cells[indices[k]] != value)
                {
                    _cells[indices[k]] = value;
                    changed = true;
                }
            }
        }
        if (changed)
            Spawn();
        return changed;
    }

    /// <summary>Cell indices of one line, ordered from the edge tiles slide toward.</summary>
    private int[] Line(char direction, int line) => direction switch
    {
        'L' => Enumerable.Range(0, _size).Select(c => line * _size + c).ToArray(),
        'R' => Enumerable.Range(0, _size).Select(c => line * _size + (_size - 1 - c)).ToArray(),
        'U' => Enumerable.Range(0, _size).Select(r => r * _size + line).ToArray(),
        'D' => Enumerable.Range(0, _size).Select(r => (_size - 1 - r) * _size + line).ToArray(),
        _ => throw new ArgumentOutOfRangeException(nameof(direction)),
    };

    private void Spawn()
    {
        var empty = Enumerable.Range(0, _cells.Length).Where(i => _cells[i] == 0).ToList();
        if (empty.Count == 0)
            return;
        var index = empty[_rng.Below(empty.Count)];
        _cells[index] = _rng.Below(10) == 0 ? 4 : 2;
    }
}
