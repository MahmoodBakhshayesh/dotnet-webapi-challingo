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
}
