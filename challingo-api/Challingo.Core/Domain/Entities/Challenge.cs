using Challingo.Core.Domain.Enums;

namespace Challingo.Core.Domain.Entities;

/// <summary>One puzzle offered to players inside a time window (a daily puzzle, a ranked round, …).</summary>
public class Challenge : BaseEntity
{
    public ChallengeKind Kind { get; set; }
    public Guid PuzzleId { get; set; }
    public Puzzle? Puzzle { get; set; }
    public DateTime OpensAtUtc { get; set; }
    public DateTime ClosesAtUtc { get; set; }

    /// <summary>Practice challenges belong to the player who created them; null for shared challenges.</summary>
    public Guid? OwnerUserId { get; set; }

    /// <summary>Unique schedule slot (e.g. <c>ranked:2026-10-05:04</c>), so scheduling can run again safely. Null for practice.</summary>
    public string? SlotKey { get; set; }

    /// <summary>The period it counts for: UTC date (<c>2026-10-05</c>) for ranked and Grand, the local date for the daily puzzle.</summary>
    public string? PeriodKey { get; set; }

    /// <summary>ISO week (<c>2026-W41</c>) the challenge belongs to, for weekly totals.</summary>
    public string? WeekKey { get; set; }

    /// <summary>Order within a set (ranked round 1–6 of the day, Grand game 1–6).</summary>
    public int Sequence { get; set; }

    /// <summary>Daily puzzle only: the local date it belongs to (players whose local date matches may play).</summary>
    public DateOnly? LocalDate { get; set; }

    /// <summary>Set once final points and payouts are done.</summary>
    public DateTime? FinalizedAtUtc { get; set; }

    /// <summary>Set once the "round opened" push went out.</summary>
    public DateTime? AnnouncedAtUtc { get; set; }
}
