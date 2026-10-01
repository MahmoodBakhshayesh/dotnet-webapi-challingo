namespace Challingo.Core.Domain.Entities;

/// <summary>One completed rewarded ad, as confirmed by the ad network's signed server callback.</summary>
public class AdReward
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }

    /// <summary>UTC date the reward counts for (max per day applies).</summary>
    public string DayKey { get; set; } = "";

    /// <summary>The network's transaction id: unique, so a callback can never reward twice.</summary>
    public string TransactionId { get; set; } = "";

    public string AdUnit { get; set; } = "";
    public DateTime RewardedAtUtc { get; set; }
}

/// <summary>Plus as last confirmed by RevenueCat (the subscriber record, not the webhook body).</summary>
public class PlusEntitlement
{
    public Guid UserId { get; set; }

    /// <summary>Plus is active while now is before this (null = lifetime / no expiry).</summary>
    public DateTime? ExpiresAtUtc { get; set; }

    public bool Active { get; set; }
    public string? ProductId { get; set; }

    /// <summary>APP_STORE, PLAY_STORE, or DEV for test grants.</summary>
    public string? Store { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}
