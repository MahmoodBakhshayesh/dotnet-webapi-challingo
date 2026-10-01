namespace Challingo.Core.Settings;

/// <summary>Competition rules (env: Competition__*).</summary>
public sealed class CompetitionOptions
{
    /// <summary>Ranked runs a player may start per UTC day (all games) without ads or Plus.</summary>
    public int FreeRankedRunsPerDay { get; set; } = 3;

    /// <summary>Below this many players a run scores against par instead of percentiles.</summary>
    public int SmallRoundThreshold { get; set; } = 50;

    /// <summary>How far ahead the Worker creates runs.</summary>
    public int ScheduleHoursAhead { get; set; } = 30;

    /// <summary>How many days ahead the Sunday Grand Challenge is created (so it can be previewed and swapped).</summary>
    public int GrandDaysAhead { get; set; } = 8;

    /// <summary>Games in the Sunday Grand Challenge.</summary>
    public int GrandGames { get; set; } = 6;

    /// <summary>Per-game overrides: <c>Competition__Runs__sudoku__EveryMinutes=90</c>. Zero/missing = the built-in default.</summary>
    public Dictionary<string, GameRunOptions> Runs { get; set; } = new(StringComparer.OrdinalIgnoreCase);

    /// <summary>Star amounts per board place (1st,2nd,3rd).</summary>
    public StarAmounts Stars { get; set; } = new();

    /// <summary>Invite links: <c>{InviteBaseUrl}{code}</c>.</summary>
    public string InviteBaseUrl { get; set; } = "https://challingo.app/g/";

    /// <summary>Lets admins move challenge windows (testing only; keep false in production).</summary>
    public bool AllowAdminTimeTravel { get; set; }

    public int RankedDifficulty { get; set; } = 2;
    public int GrandDifficulty { get; set; } = 2;

    /// <summary>Daily lottery prize (stars), shared by the winners.</summary>
    public int LotteryPot { get; set; } = 1000;
}

public sealed class GameRunOptions
{
    /// <summary>A new run starts every this many minutes (must divide a day: 15, 20, 30, 60, 120, 240…).</summary>
    public int EveryMinutes { get; set; }

    /// <summary>Extra time after joining closes for started attempts to finish.</summary>
    public int GraceMinutes { get; set; }

    /// <summary>False takes the game out of ranked runs (practice stays).</summary>
    public bool Enabled { get; set; } = true;
}

/// <summary>"1st,2nd,3rd" star amounts (comma-separated so env overrides replace the whole list).</summary>
public sealed class StarAmounts
{
    public string DayGlobal { get; set; } = "30,20,10";
    public string DayCountry { get; set; } = "10,6,3";
    public string WeekGlobal { get; set; } = "100,60,30";
    public string WeekCountry { get; set; } = "30,20,10";
    public string MonthGlobal { get; set; } = "300,200,100";
    public string MonthCountry { get; set; } = "100,60,30";
    public string GrandGlobal { get; set; } = "300,200,100";
    public string GrandCountry { get; set; } = "100,60,30";
}
