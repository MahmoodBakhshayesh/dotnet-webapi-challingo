using Challingo.Core.Settings;

namespace Challingo.Core.Competition;

/// <summary>Values are stored as ints in API responses: append new periods at the end.</summary>
public enum BoardPeriod
{
    Round,
    Day,
    Week,
    Grand,
    AllTime,
    Month,
}

/// <summary>Stars for the top 3 of each board when it closes (ties share the place). Stars are never sold.</summary>
public static class StarRewards
{
    public const int PerRewardedAd = 5;
    public const int MaxRewardedAdsPerDay = 3;

    /// <summary>Stars for <paramref name="place"/> (1–3) on a closing board; 0 otherwise (runs and all-time pay nothing).</summary>
    public static int For(StarAmounts amounts, BoardPeriod period, bool global, int place)
    {
        var table = (period, global) switch
        {
            (BoardPeriod.Day, true) => amounts.DayGlobal,
            (BoardPeriod.Day, false) => amounts.DayCountry,
            (BoardPeriod.Week, true) => amounts.WeekGlobal,
            (BoardPeriod.Week, false) => amounts.WeekCountry,
            (BoardPeriod.Month, true) => amounts.MonthGlobal,
            (BoardPeriod.Month, false) => amounts.MonthCountry,
            (BoardPeriod.Grand, true) => amounts.GrandGlobal,
            (BoardPeriod.Grand, false) => amounts.GrandCountry,
            _ => "",
        };
        var values = table.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        return place >= 1 && place <= values.Length && int.TryParse(values[place - 1], out var stars) && stars > 0 ? stars : 0;
    }

    /// <summary>Places 1–3 by score, ties sharing a place (1, 1, 3…). Zero scores never win stars.</summary>
    public static IEnumerable<(T Item, int Place)> Podium<T>(IEnumerable<T> items, Func<T, double> score)
    {
        var ordered = items.Where(i => score(i) > 0).OrderByDescending(score).ToList();
        var place = 0;
        for (var i = 0; i < ordered.Count; i++)
        {
            if (i == 0 || score(ordered[i]) != score(ordered[i - 1]))
                place = i + 1;
            if (place > 3)
                yield break;
            yield return (ordered[i], place);
        }
    }
}
