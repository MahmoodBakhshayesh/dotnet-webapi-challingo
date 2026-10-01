namespace Challingo.Core.Competition;

/// <summary>
/// Leaderboard keys. Every board has a global and a per-country version; group boards read the global
/// board filtered to the group's members.
/// </summary>
public static class BoardKeys
{
    public static string Scope(string? countryCode) =>
        string.IsNullOrEmpty(countryCode) ? "g" : $"cc:{countryCode.ToUpperInvariant()}";

    public static string Round(Guid challengeId, string? countryCode = null) => $"lb:round:{challengeId:N}:{Scope(countryCode)}";
    public static string Day(string dayKey, string? countryCode = null) => $"lb:day:{dayKey}:{Scope(countryCode)}";
    public static string Week(string weekKey, string? countryCode = null) => $"lb:week:{weekKey}:{Scope(countryCode)}";
    public static string Grand(string weekKey, string? countryCode = null) => $"lb:grand:{weekKey}:{Scope(countryCode)}";
    public static string AllTime(string? countryCode = null) => $"lb:all:{Scope(countryCode)}";

    /// <summary>SignalR topic for a challenge's live board.</summary>
    public static string Topic(Guid challengeId) => $"challenge:{challengeId:N}";

    /// <summary>SignalR topic for the live Grand board.</summary>
    public static string GrandTopic(string weekKey) => $"grand:{weekKey.ToLowerInvariant()}";
}
