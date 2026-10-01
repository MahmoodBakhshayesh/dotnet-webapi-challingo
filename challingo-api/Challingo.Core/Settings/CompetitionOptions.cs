namespace Challingo.Core.Settings;

/// <summary>Competition rules (env: Competition__*).</summary>
public sealed class CompetitionOptions
{
    /// <summary>Ranked rounds a player may start per UTC day without ads or Plus.</summary>
    public int FreeRankedRoundsPerDay { get; set; } = 1;

    /// <summary>Below this many players a round scores against par instead of percentiles.</summary>
    public int SmallRoundThreshold { get; set; } = 50;

    /// <summary>How many days ahead the Worker creates challenges.</summary>
    public int ScheduleDaysAhead { get; set; } = 8;

    /// <summary>Invite links: <c>{InviteBaseUrl}{code}</c>.</summary>
    public string InviteBaseUrl { get; set; } = "https://challingo.app/g/";

    /// <summary>Lets admins move challenge windows (testing only; keep false in production).</summary>
    public bool AllowAdminTimeTravel { get; set; }

    public int RankedDifficulty { get; set; } = 2;
    public int DailyDifficulty { get; set; } = 2;
    public int GrandDifficulty { get; set; } = 2;
}
