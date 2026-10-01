namespace Challingo.Core.Puzzles;

/// <summary>Output of a generator: what the app sees, and what only the server keeps.</summary>
public sealed record GeneratedPuzzle(string PublicJson, string SecretJson);

public enum PuzzleOutcome
{
    /// <summary>Finished successfully (a race solved, a fixed-time round completed).</summary>
    Solved,

    /// <summary>A complete but wrong answer: the attempt stays open and the clock keeps running.</summary>
    Incorrect,

    /// <summary>The attempt is over without a solve (out of guesses, hit a mine).</summary>
    Failed,

    /// <summary>Malformed input; nothing is recorded.</summary>
    Invalid,
}

/// <summary>
/// Server verdict on a final submission. <paramref name="ResultJson"/> holds the game's raw measures
/// (guesses, moves, word points…) that ranking uses besides solve time.
/// </summary>
public sealed record PuzzleVerdict(PuzzleOutcome Outcome, string? ResultJson = null, string? Message = null)
{
    public static PuzzleVerdict Solved(string? resultJson = null) => new(PuzzleOutcome.Solved, resultJson);
    public static PuzzleVerdict Incorrect(string message = "Not solved yet.") => new(PuzzleOutcome.Incorrect, null, message);
    public static PuzzleVerdict Failed(string? resultJson = null, string? message = null) => new(PuzzleOutcome.Failed, resultJson, message);
    public static PuzzleVerdict Invalid(string message) => new(PuzzleOutcome.Invalid, null, message);
}

/// <summary>Everything a game needs to judge a final submission.</summary>
/// <param name="StateJson">Server-kept progress of an interactive game (null for others).</param>
/// <param name="Elapsed">Server time since the attempt started.</param>
public sealed record PuzzleSubmission(string PublicJson, string SecretJson, string? StateJson, string SubmissionJson, TimeSpan Elapsed);

/// <summary>
/// One minigame. Generation must be deterministic: the same seed, difficulty and content always produce
/// the same puzzle, so a puzzle can be regenerated, audited or shared across servers.
/// </summary>
public interface IPuzzleGame
{
    /// <summary>Stable id used in URLs and storage, e.g. <c>sudoku</c>.</summary>
    string Key { get; }

    /// <summary>Bump when generation output changes, so stored puzzles stay explainable.</summary>
    int GeneratorVersion { get; }

    ValueTask<GeneratedPuzzle> GenerateAsync(int seed, int difficulty, CancellationToken ct = default);

    PuzzleVerdict Verify(PuzzleSubmission submission);
}

/// <summary>One move sent while playing an interactive game.</summary>
public sealed record PuzzleMove(string PublicJson, string SecretJson, string? StateJson, string MoveJson, TimeSpan Elapsed);

/// <summary>
/// Result of a move. <paramref name="StateJson"/> replaces the stored progress and is returned to the app
/// when the attempt resumes, so it must never contain secrets. <paramref name="Outcome"/> null = keep playing.
/// </summary>
public sealed record PuzzleMoveResult(
    string? StateJson,
    string ResponseJson,
    PuzzleOutcome? Outcome = null,
    string? ResultJson = null,
    string? Error = null)
{
    public static PuzzleMoveResult Invalid(string error) => new(null, "{}", null, null, error);
}

/// <summary>
/// A game the server must answer move by move because the app may not hold the answer
/// (Code Breaker, Word Guess, Mine Logic) or because time limits apply per move (Word Hunt).
/// </summary>
public interface IInteractivePuzzleGame : IPuzzleGame
{
    PuzzleMoveResult ApplyMove(PuzzleMove move);
}
