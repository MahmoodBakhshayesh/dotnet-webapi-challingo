namespace Challingo.Core.Settings;

/// <summary>Puzzle engine settings (env: Puzzles__*).</summary>
public sealed class PuzzleOptions
{
    /// <summary>HMAC key for attempt tokens. Empty = derived from Jwt:Key.</summary>
    public string AttemptTokenKey { get; set; } = "";

    /// <summary>How long a practice challenge stays open after it is created.</summary>
    public int PracticeWindowMinutes { get; set; } = 60;

    /// <summary>Default difficulty for practice puzzles (game-specific meaning).</summary>
    public int PracticeDifficulty { get; set; } = 1;
}
