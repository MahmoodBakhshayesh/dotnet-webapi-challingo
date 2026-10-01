using Challingo.Core.Domain.Enums;

namespace Challingo.Core.Domain.Entities;

/// <summary>
/// Hand-reviewed content a game builds puzzles from: Word Guess answers, Mini Crossword grids with clues.
/// Only <see cref="ContentStatus.Approved"/> items are used.
/// </summary>
public class PuzzleContent : BaseEntity
{
    public string GameKey { get; set; } = "";

    /// <summary>Unique per game (the answer word; the crossword's letter grid), so duplicates are refused.</summary>
    public string ContentKey { get; set; } = "";

    public ContentStatus Status { get; set; }

    /// <summary>Game-specific JSON (e.g. <c>{"word":"crane"}</c>, <c>{"rows":[…],"clues":{…}}</c>).</summary>
    public string PayloadJson { get; set; } = "{}";

    public string? Notes { get; set; }
    public Guid? ReviewedByUserId { get; set; }
    public DateTime? ReviewedAtUtc { get; set; }
}
