namespace Challingo.Core.Competition;

/// <summary>Random game picks for the schedule.</summary>
public static class GameDraw
{
    /// <summary>A featured game for one day of the week: not featured yet this week.</summary>
    public static string? Featured(IReadOnlyList<string> available, IReadOnlyCollection<string> usedThisWeek, Random rng) =>
        Pick(available.Where(g => !usedThisWeek.Contains(g)).ToList(), rng)
        ?? Pick(available, rng);

    /// <summary>A ranked round's game: never the same game twice in a row.</summary>
    public static string? Round(IReadOnlyList<string> available, string? previousGame, Random rng) =>
        Pick(available.Where(g => g != previousGame).ToList(), rng)
        ?? Pick(available, rng);

    private static string? Pick(IReadOnlyList<string> options, Random rng) =>
        options.Count == 0 ? null : options[rng.Next(options.Count)];
}
