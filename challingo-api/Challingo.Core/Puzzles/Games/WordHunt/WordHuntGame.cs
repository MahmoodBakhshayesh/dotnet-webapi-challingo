using Challingo.Core.Puzzles.Words;

namespace Challingo.Core.Puzzles.Games.WordHunt;

/// <summary>
/// Swipe adjacent tiles (diagonals count, no tile twice) to spell words; a fixed-time round scored by word
/// points. Each swipe is a move, so the server checks the word and the time limit. "qu" is one tile.
/// Public: <c>{size, tiles[], minLength, timeLimitSeconds}</c>; move: <c>{path:[cell…]}</c>;
/// submit (any time, e.g. when the timer ends) closes the round.
/// </summary>
public sealed class WordHuntGame(IWordDictionary dictionary) : IInteractivePuzzleGame
{
    /// <summary>Tests only: lowers the "enough words on the board" bar.</summary>
    internal int? MinWordsOverride { get; init; }

    /// <summary>Swipes this long after the limit still count (network latency).</summary>
    public static readonly TimeSpan Grace = TimeSpan.FromSeconds(3);

    private const int MaxTries = 400;

    // Classic letter dice ("q" faces are the "qu" tile).
    private static readonly string[] Dice4 =
    [
        "aaeegn", "abbjoo", "achops", "affkps", "aoottw", "cimotu", "deilrx", "delrvy",
        "distty", "eeghnw", "eeinsu", "ehrtvw", "eiosst", "elrtty", "himnuq", "hlnnrz",
    ];

    private static readonly string[] Dice5 =
    [
        "aaafrs", "aaeeee", "aafirs", "adennn", "aeeeem", "aeegmu", "aegmnn", "afirsy", "bjkqxz",
        "ccenst", "ceiilt", "ceilpt", "ceipst", "ddhnot", "dhhlor", "dhlnor", "dhlnor", "eiiitt",
        "emottt", "ensssu", "fiprsy", "gorrvw", "iprrry", "nootuw", "ooottu",
    ];

    public string Key => "word-hunt";
    public int GeneratorVersion => 1;

    public ValueTask<GeneratedPuzzle> GenerateAsync(int seed, int difficulty, CancellationToken ct = default)
    {
        if (!dictionary.IsLoaded)
            throw new PuzzleContentUnavailableException("The word list is not loaded.");

        var (size, minLength, minWords) = difficulty <= 2 ? (4, 3, 40) : (5, 4, 60);
        var dice = size == 4 ? Dice4 : Dice5;
        var rng = new Random(seed);
        for (var attempt = 0; attempt < MaxTries; attempt++)
        {
            var order = dice.ToArray();
            rng.Shuffle(order);
            var tiles = new string[order.Length];
            for (var i = 0; i < order.Length; i++)
            {
                var face = order[i][rng.Next(order[i].Length)];
                tiles[i] = face == 'q' ? "qu" : face.ToString();
            }

            var words = FindAllWords(tiles, size, minLength);
            if (words.Count < (MinWordsOverride ?? minWords))
                continue;

            return ValueTask.FromResult(new GeneratedPuzzle(
                PuzzleJson.Write(new Public(size, tiles, minLength, 150)),
                PuzzleJson.Write(new Secret(words.Order(StringComparer.Ordinal).ToArray()))));
        }
        throw new InvalidOperationException("Could not generate a Word Hunt board with enough words.");
    }

    public PuzzleMoveResult ApplyMove(PuzzleMove move)
    {
        var puzzle = PuzzleJson.Read<Public>(move.PublicJson);
        var words = PuzzleJson.Read<Secret>(move.SecretJson).Words.ToHashSet(StringComparer.Ordinal);
        var state = move.StateJson is null ? new State([], 0, 0) : PuzzleJson.Read<State>(move.StateJson);

        var path = PuzzleJson.TryRead<Move>(move.MoveJson)?.Path;
        if (path is null || path.Length == 0 || path.Length > puzzle.Tiles.Length)
            return PuzzleMoveResult.Invalid("A move is {\"path\": [cell…]}.");

        if (move.Elapsed > TimeSpan.FromSeconds(puzzle.TimeLimitSeconds) + Grace)
            return Reply(state, new Swipe("", false, 0, "time"));

        if (!IsPath(path, puzzle.Size))
            return Reply(state with { Invalid = state.Invalid + 1 }, new Swipe("", false, 0, "path"));

        var word = string.Concat(path.Select(i => puzzle.Tiles[i]));
        if (word.Length < puzzle.MinLength)
            return Reply(state with { Invalid = state.Invalid + 1 }, new Swipe(word, false, 0, "short"));
        if (state.Found.Any(f => f.Word == word))
            return Reply(state, new Swipe(word, false, 0, "repeat"));
        if (!words.Contains(word))
            return Reply(state with { Invalid = state.Invalid + 1 }, new Swipe(word, false, 0, "unknown"));

        var points = Points(word);
        var found = state.Found.Append(new Found(word, points)).ToList();
        return Reply(new State(found, state.Score + points, state.Invalid), new Swipe(word, true, points, null));
    }

    /// <summary>Ends the round; the score is what the server already counted.</summary>
    public PuzzleVerdict Verify(PuzzleSubmission submission)
    {
        var state = submission.StateJson is null ? new State([], 0, 0) : PuzzleJson.Read<State>(submission.StateJson);
        return PuzzleVerdict.Solved(PuzzleJson.Write(new { points = state.Score, words = state.Found.Count, invalid = state.Invalid }));
    }

    /// <summary>Classic scoring: 3–4 letters 1, 5 → 2, 6 → 3, 7 → 5, 8+ → 11.</summary>
    public static int Points(string word) => word.Length switch
    {
        <= 4 => 1,
        5 => 2,
        6 => 3,
        7 => 5,
        _ => 11,
    };

    private HashSet<string> FindAllWords(string[] tiles, int size, int minLength)
    {
        var found = new HashSet<string>(StringComparer.Ordinal);
        var used = new bool[tiles.Length];
        var letters = new System.Text.StringBuilder();

        void Walk(int cell)
        {
            used[cell] = true;
            letters.Append(tiles[cell]);
            var text = letters.ToString();
            if (dictionary.HasPrefix(text))
            {
                if (letters.Length >= minLength && dictionary.Contains(text))
                    found.Add(text);
                foreach (var n in Neighbours(cell, size))
                    if (!used[n])
                        Walk(n);
            }
            letters.Length -= tiles[cell].Length;
            used[cell] = false;
        }

        for (var cell = 0; cell < tiles.Length; cell++)
            Walk(cell);
        return found;
    }

    private static bool IsPath(int[] path, int size)
    {
        var seen = new HashSet<int>();
        for (var k = 0; k < path.Length; k++)
        {
            if (path[k] < 0 || path[k] >= size * size || !seen.Add(path[k]))
                return false;
            if (k > 0)
            {
                int ra = path[k - 1] / size, ca = path[k - 1] % size, rb = path[k] / size, cb = path[k] % size;
                if (Math.Max(Math.Abs(ra - rb), Math.Abs(ca - cb)) != 1)
                    return false;
            }
        }
        return true;
    }

    private static IEnumerable<int> Neighbours(int cell, int size)
    {
        int r = cell / size, c = cell % size;
        for (var dr = -1; dr <= 1; dr++)
        for (var dc = -1; dc <= 1; dc++)
        {
            int nr = r + dr, nc = c + dc;
            if ((dr != 0 || dc != 0) && nr >= 0 && nr < size && nc >= 0 && nc < size)
                yield return nr * size + nc;
        }
    }

    private static PuzzleMoveResult Reply(State state, Swipe swipe) =>
        new(PuzzleJson.Write(state), PuzzleJson.Write(new { swipe.Word, swipe.Valid, swipe.Points, swipe.Reason, score = state.Score }));

    private sealed record Public(int Size, string[] Tiles, int MinLength, int TimeLimitSeconds);
    private sealed record Secret(string[] Words);
    private sealed record Move(int[]? Path);
    private sealed record Found(string Word, int Points);
    private sealed record State(List<Found> Found, int Score, int Invalid);
    private sealed record Swipe(string Word, bool Valid, int Points, string? Reason);
}
