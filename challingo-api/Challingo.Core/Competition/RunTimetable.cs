using Challingo.Core.Settings;

namespace Challingo.Core.Competition;

/// <summary>How often each game runs and how long a started attempt may run past the join close.</summary>
public sealed record GameRun(string GameKey, TimeSpan Every, TimeSpan Grace);

public static class RunTimetable
{
    /// <summary>Built-in timers, sized to how long a game takes. Mini Crossword is limited by hand-written content.</summary>
    private static readonly Dictionary<string, (int Every, int Grace)> Defaults = new(StringComparer.OrdinalIgnoreCase)
    {
        ["path-link"] = (30, 10),
        ["code-breaker"] = (30, 10),
        ["word-guess"] = (30, 10),
        ["word-hunt"] = (30, 5),
        ["mine-logic"] = (60, 15),
        ["number-merge"] = (60, 15),
        ["sudoku"] = (120, 30),
        ["kakuro"] = (120, 30),
        ["nonogram"] = (120, 30),
        ["mini-crossword"] = (240, 30),
    };

    private const int DayMinutes = 24 * 60;

    /// <summary>The game's timer, or null when it is switched off for ranked runs.</summary>
    public static GameRun? For(string gameKey, CompetitionOptions options)
    {
        options.Runs.TryGetValue(gameKey, out var custom);
        if (custom is { Enabled: false })
            return null;

        var (every, grace) = Defaults.TryGetValue(gameKey, out var d) ? d : (60, 15);
        if (custom is { EveryMinutes: > 0 } && DayMinutes % custom.EveryMinutes == 0)
            every = custom.EveryMinutes;
        if (custom is { GraceMinutes: > 0 })
            grace = custom.GraceMinutes;
        return new GameRun(gameKey, TimeSpan.FromMinutes(every), TimeSpan.FromMinutes(grace));
    }
}
