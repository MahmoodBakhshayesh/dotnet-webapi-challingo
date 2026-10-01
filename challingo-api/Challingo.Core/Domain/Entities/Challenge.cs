using Challingo.Core.Domain.Enums;

namespace Challingo.Core.Domain.Entities;

/// <summary>One puzzle offered to players inside a time window (a ranked run, a Grand Challenge game, practice).</summary>
public class Challenge : BaseEntity
{
    public ChallengeKind Kind { get; set; }
    public Guid PuzzleId { get; set; }
    public Puzzle? Puzzle { get; set; }

    /// <summary>The puzzle's game, copied here so boards can group runs without loading puzzles.</summary>
    public string GameKey { get; set; } = "";

    public DateTime OpensAtUtc { get; set; }

    /// <summary>Players may start until this time (the end of the run's slot).</summary>
    public DateTime JoinClosesAtUtc { get; set; }

    /// <summary>Started attempts may finish until this time (join close + the game's grace).</summary>
    public DateTime ClosesAtUtc { get; set; }

    /// <summary>Practice challenges belong to the player who created them; null for shared challenges.</summary>
    public Guid? OwnerUserId { get; set; }

    /// <summary>Unique schedule slot (<c>run:sudoku:2026-10-05T0400</c>, <c>grand:2026-10-11:1</c>), so scheduling can run again safely. Null for practice.</summary>
    public string? SlotKey { get; set; }

    /// <summary>UTC date the run opens on (<c>2026-10-05</c>): its day board.</summary>
    public string? PeriodKey { get; set; }

    /// <summary>ISO week (<c>2026-W41</c>): its week board.</summary>
    public string? WeekKey { get; set; }

    /// <summary>UTC month (<c>2026-10</c>): its month board.</summary>
    public string? MonthKey { get; set; }

    /// <summary>Run number within the UTC day for this game (1 = the run at 00:00), or the Grand game number.</summary>
    public int Sequence { get; set; }

    /// <summary>Set once final points are done.</summary>
    public DateTime? FinalizedAtUtc { get; set; }

    /// <summary>Set once the "run opened" push went out.</summary>
    public DateTime? AnnouncedAtUtc { get; set; }
}
