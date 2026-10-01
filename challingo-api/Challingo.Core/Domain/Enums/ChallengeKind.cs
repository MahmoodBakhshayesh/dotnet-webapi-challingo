namespace Challingo.Core.Domain.Enums;

public enum ChallengeKind
{
    /// <summary>Ad-hoc, unranked; created on demand (also used to test the engine end to end).</summary>
    Practice = 0,
    /// <summary>Retired (the local-date daily puzzle); kept so stored values keep their meaning.</summary>
    Daily = 1,

    /// <summary>A ranked run: every game repeats on its own UTC timer.</summary>
    Ranked = 2,

    /// <summary>One game of the Sunday Grand Challenge.</summary>
    Grand = 3,
}
