namespace Challingo.Core.Competition;

/// <summary>Random game picks for the Grand Challenge.</summary>
public static class GameDraw
{
    /// <summary>Up to <paramref name="count"/> different games in random order.</summary>
    public static List<string> Distinct(IReadOnlyList<string> available, int count, Random rng) =>
        available.OrderBy(_ => rng.Next()).Take(count).ToList();
}
