namespace Challingo.Core.Puzzles.Games.CodeBreaker;

/// <summary>
/// Guess a hidden colour code (repeats allowed). Each guess is answered by the server with
/// <c>exact</c> (right colour, right place) and <c>partial</c> (right colour, wrong place).
/// Public: <c>{pegs, colors, maxGuesses}</c>; move: <c>{guess:[0..colors-1]}</c>.
/// </summary>
public sealed class CodeBreakerGame : IInteractivePuzzleGame
{
    public string Key => "code-breaker";
    public int GeneratorVersion => 1;

    public ValueTask<GeneratedPuzzle> GenerateAsync(int seed, int difficulty, CancellationToken ct = default)
    {
        var (pegs, colors, maxGuesses) = difficulty switch
        {
            <= 1 => (4, 6, 10),
            2 => (4, 6, 8),
            3 => (5, 7, 10),
            _ => (5, 8, 10),
        };
        var rng = new Random(seed);
        var code = Enumerable.Range(0, pegs).Select(_ => rng.Next(colors)).ToArray();
        return ValueTask.FromResult(new GeneratedPuzzle(
            PuzzleJson.Write(new Public(pegs, colors, maxGuesses)),
            PuzzleJson.Write(new Secret(code))));
    }

    public PuzzleMoveResult ApplyMove(PuzzleMove move)
    {
        var puzzle = PuzzleJson.Read<Public>(move.PublicJson);
        var secret = PuzzleJson.Read<Secret>(move.SecretJson);
        var state = move.StateJson is null ? new State([]) : PuzzleJson.Read<State>(move.StateJson);

        var guess = PuzzleJson.TryRead<Move>(move.MoveJson)?.Guess;
        if (guess is null || guess.Length != puzzle.Pegs || guess.Any(c => c < 0 || c >= puzzle.Colors))
            return PuzzleMoveResult.Invalid($"A guess is {puzzle.Pegs} colours from 0 to {puzzle.Colors - 1}.");
        if (state.Guesses.Count >= puzzle.MaxGuesses)
            return PuzzleMoveResult.Invalid("No guesses left.");

        var (exact, partial) = Score(secret.Code, guess, puzzle.Colors);
        var guesses = state.Guesses.Append(new Feedback(guess, exact, partial)).ToList();
        var solved = exact == puzzle.Pegs;
        var over = solved || guesses.Count >= puzzle.MaxGuesses;

        var response = PuzzleJson.Write(new
        {
            exact,
            partial,
            remaining = puzzle.MaxGuesses - guesses.Count,
            code = over ? secret.Code : null,
        });
        return new PuzzleMoveResult(
            PuzzleJson.Write(new State(guesses)),
            response,
            over ? (solved ? PuzzleOutcome.Solved : PuzzleOutcome.Failed) : null,
            over ? PuzzleJson.Write(new { guesses = guesses.Count }) : null);
    }

    /// <summary>Submitting without cracking the code means giving up.</summary>
    public PuzzleVerdict Verify(PuzzleSubmission submission)
    {
        var guesses = submission.StateJson is null ? 0 : PuzzleJson.Read<State>(submission.StateJson).Guesses.Count;
        return PuzzleVerdict.Failed(PuzzleJson.Write(new { guesses }), "Gave up.");
    }

    public static (int Exact, int Partial) Score(int[] code, int[] guess, int colors)
    {
        int exact = 0, common = 0;
        var codeCounts = new int[colors];
        var guessCounts = new int[colors];
        for (var i = 0; i < code.Length; i++)
        {
            if (code[i] == guess[i])
                exact++;
            codeCounts[code[i]]++;
            guessCounts[guess[i]]++;
        }
        for (var c = 0; c < colors; c++)
            common += Math.Min(codeCounts[c], guessCounts[c]);
        return (exact, common - exact);
    }

    private sealed record Public(int Pegs, int Colors, int MaxGuesses);
    private sealed record Secret(int[] Code);
    private sealed record Move(int[]? Guess);
    private sealed record Feedback(int[] Guess, int Exact, int Partial);
    private sealed record State(List<Feedback> Guesses);
}
