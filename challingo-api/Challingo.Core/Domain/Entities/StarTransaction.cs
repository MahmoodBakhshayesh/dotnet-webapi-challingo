namespace Challingo.Core.Domain.Entities;

/// <summary>One star award. <see cref="RefKey"/> is unique per player, so a payout can never happen twice.</summary>
public class StarTransaction : BaseEntity
{
    public Guid UserId { get; set; }
    public int Amount { get; set; }

    /// <summary>e.g. <c>round:{challengeId}:global:1</c>, <c>day:2026-10-05:cc:DE:2</c>, <c>week:2026-W41:global:1</c>.</summary>
    public string RefKey { get; set; } = "";
}
