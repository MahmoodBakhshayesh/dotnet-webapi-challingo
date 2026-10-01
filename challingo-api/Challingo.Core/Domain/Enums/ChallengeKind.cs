namespace Challingo.Core.Domain.Enums;

public enum ChallengeKind
{
    /// <summary>Ad-hoc, unranked; created on demand (also used to test the engine end to end).</summary>
    Practice = 0,
    Daily = 1,
    Ranked = 2,
    Grand = 3,
}
