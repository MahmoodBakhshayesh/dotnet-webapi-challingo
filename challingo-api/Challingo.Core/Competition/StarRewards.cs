namespace Challingo.Core.Competition;

public enum BoardPeriod
{
    Round,
    Day,
    Week,
    Grand,
    AllTime,
}

/// <summary>Stars for the top 3 of each board when it closes (ties share the place). Stars are never sold.</summary>
public static class StarRewards
{
    public const int PerRewardedAd = 5;
    public const int MaxRewardedAdsPerDay = 3;

    /// <summary>Stars for <paramref name="place"/> (1–3); 0 otherwise. The Grand board pays like a daily board.</summary>
    public static int For(BoardPeriod period, bool global, int place)
    {
        int[] table = (period, global) switch
        {
            (BoardPeriod.Round, true) => [10, 6, 3],
            (BoardPeriod.Round, false) => [3, 2, 1],
            (BoardPeriod.Day or BoardPeriod.Grand, true) => [30, 20, 10],
            (BoardPeriod.Day or BoardPeriod.Grand, false) => [10, 6, 3],
            (BoardPeriod.Week, true) => [300, 200, 100],
            (BoardPeriod.Week, false) => [100, 60, 30],
            _ => [],
        };
        return place >= 1 && place <= table.Length ? table[place - 1] : 0;
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
