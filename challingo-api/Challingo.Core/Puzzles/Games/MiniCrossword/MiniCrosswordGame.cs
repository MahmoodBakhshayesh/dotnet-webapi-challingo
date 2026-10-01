using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.Puzzles.Content;

namespace Challingo.Core.Puzzles.Games.MiniCrossword;

/// <summary>
/// A small crossword from reviewed content. Content: <c>{rows:["#CAT#",…], clues:{across:{"1":"…"}, down:{…}}}</c>
/// with <c>#</c> for blocks. Public: <c>{width, height, blocks[], across:[{n, cells[], clue}], down:[…]}</c>;
/// submission: <c>{letters:"…"}</c> row-major (anything at blocks).
/// </summary>
public sealed class MiniCrosswordGame(IPuzzleContentRepository content) : IPuzzleGame
{
    public const string GameKey = "mini-crossword";

    public string Key => GameKey;
    public int GeneratorVersion => 1;

    public async ValueTask<GeneratedPuzzle> GenerateAsync(int seed, int difficulty, CancellationToken ct = default)
    {
        var puzzles = await content.GetApprovedAsync(Key, ct);
        if (puzzles.Count == 0)
            throw new PuzzleContentUnavailableException("No approved crosswords yet.");

        var pick = PuzzleJson.Read<CrosswordPayload>(puzzles[new Random(seed).Next(puzzles.Count)].PayloadJson);
        var layout = CrosswordLayout.Parse(pick.Rows) ?? throw new InvalidOperationException("Stored crossword is malformed.");
        Entry ToEntry(CrosswordEntry e, Dictionary<string, string> clues) => new(e.Number, e.Cells, clues[e.Number.ToString()]);

        return new GeneratedPuzzle(
            PuzzleJson.Write(new Public(
                layout.Width,
                layout.Height,
                layout.Blocks,
                layout.Across.Select(e => ToEntry(e, pick.Clues.Across)).ToArray(),
                layout.Down.Select(e => ToEntry(e, pick.Clues.Down)).ToArray())),
            PuzzleJson.Write(new Secret(string.Concat(pick.Rows))));
    }

    public PuzzleVerdict Verify(PuzzleSubmission submission)
    {
        var puzzle = PuzzleJson.Read<Public>(submission.PublicJson);
        var answer = PuzzleJson.Read<Secret>(submission.SecretJson).Letters;
        var letters = PuzzleJson.TryRead<Submission>(submission.SubmissionJson)?.Letters?.ToUpperInvariant();
        if (letters is null || letters.Length != answer.Length)
            return PuzzleVerdict.Invalid($"Expected {answer.Length} letters.");

        var blocks = puzzle.Blocks.ToHashSet();
        for (var i = 0; i < answer.Length; i++)
        {
            if (blocks.Contains(i))
                continue;
            if (letters[i] is < 'A' or > 'Z')
                return PuzzleVerdict.Incorrect("Fill every square.");
            if (letters[i] != answer[i])
                return PuzzleVerdict.Incorrect("Some answers are wrong.");
        }
        return PuzzleVerdict.Solved();
    }

    private sealed record Entry(int N, int[] Cells, string Clue);
    private sealed record Public(int Width, int Height, int[] Blocks, Entry[] Across, Entry[] Down);
    private sealed record Secret(string Letters);
    private sealed record Submission(string? Letters);
}

public sealed record CrosswordClues(Dictionary<string, string> Across, Dictionary<string, string> Down);
public sealed record CrosswordPayload(string[] Rows, CrosswordClues Clues);
public sealed record CrosswordEntry(int Number, int[] Cells);

/// <summary>Numbers a grid the standard way: a white cell starts an entry when the previous cell is a block or edge.</summary>
public sealed record CrosswordLayout(int Width, int Height, int[] Blocks, CrosswordEntry[] Across, CrosswordEntry[] Down)
{
    public static CrosswordLayout? Parse(string[] rows)
    {
        if (rows.Length is < 3 or > 9 || rows.Any(r => r.Length != rows[0].Length) || rows[0].Length is < 3 or > 9)
            return null;
        if (rows.Any(r => r.Any(c => c != '#' && c is < 'A' or > 'Z')))
            return null;

        int height = rows.Length, width = rows[0].Length;
        bool White(int r, int c) => r >= 0 && r < height && c >= 0 && c < width && rows[r][c] != '#';

        var across = new List<CrosswordEntry>();
        var down = new List<CrosswordEntry>();
        var number = 0;
        for (var r = 0; r < height; r++)
        for (var c = 0; c < width; c++)
        {
            if (!White(r, c))
                continue;
            var startsAcross = !White(r, c - 1) && White(r, c + 1);
            var startsDown = !White(r - 1, c) && White(r + 1, c);
            if (!startsAcross && !startsDown)
                continue;
            number++;
            if (startsAcross)
                across.Add(new CrosswordEntry(number, Enumerable.Range(c, width - c).TakeWhile(cc => White(r, cc)).Select(cc => r * width + cc).ToArray()));
            if (startsDown)
                down.Add(new CrosswordEntry(number, Enumerable.Range(r, height - r).TakeWhile(rr => White(rr, c)).Select(rr => rr * width + c).ToArray()));
        }

        var blocks = Enumerable.Range(0, width * height).Where(i => !White(i / width, i % width)).ToArray();
        return new CrosswordLayout(width, height, blocks, across.ToArray(), down.ToArray());
    }
}

/// <summary>Grid 3–9 wide of A–Z and '#'; every entry has a clue and there are no extra clues.</summary>
public sealed class MiniCrosswordContentValidator : IPuzzleContentValidator
{
    public string GameKey => MiniCrosswordGame.GameKey;

    public ContentValidation Validate(string payloadJson)
    {
        var payload = PuzzleJson.TryRead<CrosswordPayload>(payloadJson);
        if (payload?.Rows is null || payload.Clues?.Across is null || payload.Clues.Down is null)
            return ContentValidation.Fail("Expected {rows:[…], clues:{across:{…}, down:{…}}}.");

        var rows = payload.Rows.Select(r => r.Trim().ToUpperInvariant()).ToArray();
        var layout = CrosswordLayout.Parse(rows);
        if (layout is null)
            return ContentValidation.Fail("Rows must be equal length (3–9) using A–Z and '#'.");

        static string? Check(CrosswordEntry[] entries, Dictionary<string, string> clues, string direction)
        {
            var numbers = entries.Select(e => e.Number.ToString()).ToHashSet();
            var missing = numbers.Where(n => !clues.TryGetValue(n, out var clue) || string.IsNullOrWhiteSpace(clue)).ToList();
            if (missing.Count > 0)
                return $"Missing {direction} clue(s): {string.Join(", ", missing)}.";
            var extra = clues.Keys.Where(k => !numbers.Contains(k)).ToList();
            if (extra.Count > 0)
                return $"No {direction} entry numbered {string.Join(", ", extra)}.";
            return clues.Values.Any(v => v.Length > 120) ? "Clues are at most 120 characters." : null;
        }

        var error = Check(layout.Across, payload.Clues.Across, "across") ?? Check(layout.Down, payload.Clues.Down, "down");
        if (error is not null)
            return ContentValidation.Fail(error);

        var clean = new CrosswordPayload(rows, new CrosswordClues(
            payload.Clues.Across.ToDictionary(kv => kv.Key, kv => kv.Value.Trim()),
            payload.Clues.Down.ToDictionary(kv => kv.Key, kv => kv.Value.Trim())));
        return ContentValidation.Ok(PuzzleJson.Write(clean), string.Join("/", rows));
    }
}
