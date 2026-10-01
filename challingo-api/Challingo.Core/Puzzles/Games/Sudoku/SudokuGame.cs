using System.Text.Json;

namespace Challingo.Core.Puzzles.Games.Sudoku;

/// <summary>
/// Classic Sudoku with a unique solution. Public: <c>{size, boxRows, boxCols, givens[]}</c>;
/// secret: <c>{solution[]}</c>; submission: <c>{cells[]}</c> — all row-major, 0 = empty.
/// </summary>
public sealed class SudokuGame : IPuzzleGame
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public string Key => "sudoku";
    public int GeneratorVersion => 1;

    public ValueTask<GeneratedPuzzle> GenerateAsync(int seed, int difficulty, CancellationToken ct = default) =>
        ValueTask.FromResult(Generate(seed, difficulty));

    public GeneratedPuzzle Generate(int seed, int difficulty)
    {
        var shape = SudokuShape.ForDifficulty(difficulty);
        var rng = new Random(seed);
        var solution = SudokuSolver.Fill(shape, rng);
        var givens = (int[])solution.Clone();

        // Remove cells in a seeded random order, keeping each removal only while the solution stays unique.
        var order = Enumerable.Range(0, shape.Cells).ToArray();
        for (var i = order.Length - 1; i > 0; i--)
        {
            var j = rng.Next(i + 1);
            (order[i], order[j]) = (order[j], order[i]);
        }

        var remaining = shape.Cells;
        foreach (var cell in order)
        {
            if (remaining <= shape.TargetGivens)
                break;
            var saved = givens[cell];
            givens[cell] = 0;
            if (SudokuSolver.CountSolutions(shape, givens) == 1)
                remaining--;
            else
                givens[cell] = saved;
        }

        return new GeneratedPuzzle(
            JsonSerializer.Serialize(new SudokuPublic(shape.Size, shape.BoxRows, shape.BoxCols, givens), Json),
            JsonSerializer.Serialize(new SudokuSecret(solution), Json));
    }

    public PuzzleVerdict Verify(PuzzleSubmission input)
    {
        var puzzle = JsonSerializer.Deserialize<SudokuPublic>(input.PublicJson, Json)!;
        var secret = JsonSerializer.Deserialize<SudokuSecret>(input.SecretJson, Json)!;

        SudokuSubmission? submission;
        try
        {
            submission = JsonSerializer.Deserialize<SudokuSubmission>(input.SubmissionJson, Json);
        }
        catch (JsonException)
        {
            return PuzzleVerdict.Invalid("Submission is not valid JSON.");
        }

        var cells = submission?.Cells;
        if (cells is null || cells.Length != puzzle.Givens.Length)
            return PuzzleVerdict.Invalid($"Expected {puzzle.Givens.Length} cells.");

        for (var i = 0; i < cells.Length; i++)
        {
            if (puzzle.Givens[i] != 0 && cells[i] != puzzle.Givens[i])
                return PuzzleVerdict.Invalid("A given cell was changed.");
        }

        // The solution is unique, so a correct grid must equal it.
        return cells.AsSpan().SequenceEqual(secret.Solution)
            ? PuzzleVerdict.Solved()
            : PuzzleVerdict.Incorrect("Some cells are wrong.");
    }

    private sealed record SudokuPublic(int Size, int BoxRows, int BoxCols, int[] Givens);
    private sealed record SudokuSecret(int[] Solution);
    private sealed record SudokuSubmission(int[]? Cells);
}
