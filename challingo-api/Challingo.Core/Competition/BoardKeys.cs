namespace Challingo.Core.Competition;

/// <summary>
/// Leaderboard keys. Every board has a global and a per-country version; group boards read the global
/// board filtered to the group's members.
/// </summary>
public static class BoardKeys
{
    public static string Scope(string? countryCode) =>
        string.IsNullOrEmpty(countryCode) ? "g" : $"cc:{countryCode.ToUpperInvariant()}";

    /// <summary>One run (or Grand game): rank scores, live.</summary>
    public static string Run(Guid challengeId, string? countryCode = null) => $"lb:run:{challengeId:N}:{Scope(countryCode)}";

    /// <summary>A game's day / week / month / all-time totals (key: date, ISO week, month, "all").</summary>
    public static string Game(string gameKey, BoardPeriod period, string key, string? countryCode = null) =>
        $"lb:game:{gameKey}:{period.ToString().ToLowerInvariant()}:{key}:{Scope(countryCode)}";

    public static string Grand(string weekKey, string? countryCode = null) => $"lb:grand:{weekKey}:{Scope(countryCode)}";

    /// <summary>SignalR topic for a run's live board.</summary>
    public static string Topic(Guid challengeId) => $"challenge:{challengeId:N}";

    /// <summary>SignalR topic for the live Grand board.</summary>
    public static string GrandTopic(string weekKey) => $"grand:{weekKey.ToLowerInvariant()}";

    public const string AllTimeKey = "all";
}
