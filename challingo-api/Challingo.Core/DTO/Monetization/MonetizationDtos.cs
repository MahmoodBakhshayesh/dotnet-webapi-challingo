namespace Challingo.Core.DTO.Monetization;

public sealed class PlusStatusDto
{
    public bool Active { get; init; }
    public DateTime? ExpiresAtUtc { get; init; }
    public string? Store { get; init; }
}

/// <summary>Everything the app needs for the ad button and the Plus screen.</summary>
public sealed class MonetizationStatusDto
{
    public required PlusStatusDto Plus { get; init; }
    public int AdsToday { get; init; }
    public int AdsPerDay { get; init; }
    public int RunsPerAd { get; init; }
    public int StarsPerAd { get; init; }

    /// <summary>The player id to pass to the ad network (server-side verification) and RevenueCat.</summary>
    public required string RewardUserId { get; init; }

    /// <summary>Test grants allowed (development only).</summary>
    public bool DevRewards { get; init; }
}

/// <summary>A RevenueCat subscriber's entitlement, read from the RevenueCat API.</summary>
public sealed record RevenueCatEntitlement(bool Active, DateTime? ExpiresAtUtc, string? ProductId, string? Store);
