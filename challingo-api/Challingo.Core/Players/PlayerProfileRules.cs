using System.Text.RegularExpressions;
using Challingo.Core.Domain.Entities;

namespace Challingo.Core.Players;

public static partial class PlayerProfileRules
{
    /// <summary>A player may change their zone once per this period (the first set after sign-up is free).</summary>
    public static readonly TimeSpan TimeZoneChangeCooldown = TimeSpan.FromDays(30);

    public static DateTime? NextTimeZoneChangeAtUtc(PlayerProfile profile) =>
        profile.TimeZoneChangedAtUtc is { } changed ? changed + TimeZoneChangeCooldown : null;

    /// <summary>
    /// The zone that decides the player's local date right now: a fresh change only applies from the next
    /// local midnight of the previous zone, so switching zones cannot replay or skip a day.
    /// </summary>
    public static string EffectiveTimeZone(PlayerProfile profile, DateTime utcNow)
    {
        if (profile.PreviousTimeZoneId is { } previous && profile.TimeZoneChangedAtUtc is { } changed
            && utcNow < PlayerTimeZones.NextLocalMidnightUtc(previous, changed))
        {
            return previous;
        }
        return profile.TimeZoneId;
    }

    public static bool IsValidDisplayName(string? name) =>
        name is not null && DisplayNamePattern().IsMatch(name);

    public static string DefaultDisplayName(Random? rng = null) =>
        $"Player{(rng ?? Random.Shared).Next(1000, 10000)}";

    [GeneratedRegex(@"^[\p{L}\p{N}_\- ]{3,20}$")]
    private static partial Regex DisplayNamePattern();
}
