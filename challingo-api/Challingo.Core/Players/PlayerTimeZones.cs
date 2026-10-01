using NodaTime;
using NodaTime.TimeZones;

namespace Challingo.Core.Players;

/// <summary>
/// IANA time zone helpers. The country for country boards comes from the zone (tzdb zone.tab),
/// never from IP. The player's "today" is always computed here from server UTC time.
/// </summary>
public static class PlayerTimeZones
{
    public const string Utc = "Etc/UTC";

    private static readonly TzdbDateTimeZoneSource Source = TzdbDateTimeZoneSource.Default;

    private static readonly Dictionary<string, string> CountryByZone =
        (Source.ZoneLocations ?? [])
            .GroupBy(l => l.ZoneId, StringComparer.Ordinal)
            .ToDictionary(g => g.Key, g => g.First().CountryCode, StringComparer.Ordinal);

    /// <summary>Resolves aliases (e.g. <c>Asia/Calcutta</c> → <c>Asia/Kolkata</c>); false for unknown ids.</summary>
    public static bool TryNormalize(string? zoneId, out string canonical)
    {
        canonical = Utc;
        if (string.IsNullOrWhiteSpace(zoneId))
            return false;

        var id = zoneId.Trim();
        if (Source.CanonicalIdMap.TryGetValue(id, out var mapped))
        {
            canonical = mapped;
            return true;
        }
        return false;
    }

    /// <summary>ISO 3166-1 alpha-2 country for a canonical zone; null for zones like UTC.</summary>
    public static string? CountryFor(string canonicalZoneId) =>
        CountryByZone.GetValueOrDefault(canonicalZoneId);

    public static DateOnly LocalDate(string zoneId, DateTime utcNow)
    {
        var zone = DateTimeZoneProviders.Tzdb.GetZoneOrNull(zoneId) ?? DateTimeZone.Utc;
        var local = Instant.FromDateTimeUtc(DateTime.SpecifyKind(utcNow, DateTimeKind.Utc)).InZone(zone).Date;
        return new DateOnly(local.Year, local.Month, local.Day);
    }

    /// <summary>The next local midnight in <paramref name="zoneId"/>, as UTC.</summary>
    public static DateTime NextLocalMidnightUtc(string zoneId, DateTime utcNow)
    {
        var zone = DateTimeZoneProviders.Tzdb.GetZoneOrNull(zoneId) ?? DateTimeZone.Utc;
        var today = Instant.FromDateTimeUtc(DateTime.SpecifyKind(utcNow, DateTimeKind.Utc)).InZone(zone).Date;
        return zone.AtStartOfDay(today.PlusDays(1)).ToDateTimeUtc();
    }
}
