using Challingo.Core.Competition;
using Challingo.Core.Domain.Enums;

namespace Challingo.Core.DTO.Competition;

public enum ChallengeState
{
    Upcoming,

    /// <summary>Joinable now.</summary>
    Open,

    /// <summary>No more joins (started attempts may still be finishing).</summary>
    Closed,
}

/// <summary>The player's own attempt on a challenge.</summary>
public sealed class MyAttemptDto
{
    public Guid AttemptId { get; init; }
    public AttemptStatus Status { get; init; }
    public long? ElapsedMs { get; init; }

    /// <summary>Final points (null until the run is finalized).</summary>
    public int? Points { get; init; }
    public int? Rank { get; init; }
}

/// <summary>One ranked run or Grand game.</summary>
public sealed class RunCardDto
{
    public Guid ChallengeId { get; init; }
    public ChallengeKind Kind { get; init; }
    public required string GameKey { get; init; }
    public int Sequence { get; init; }
    public DateTime OpensAtUtc { get; init; }
    public DateTime JoinClosesAtUtc { get; init; }
    public DateTime ClosesAtUtc { get; init; }
    public ChallengeState State { get; init; }
    public bool Finalized { get; init; }
    public MyAttemptDto? My { get; init; }
}

/// <summary>A game in the lobby: the run you can join now, the next one, and your day so far.</summary>
public sealed class GameLobbyDto
{
    public required string GameKey { get; init; }
    public int EveryMinutes { get; init; }
    public RunCardDto? Current { get; init; }
    public RunCardDto? Next { get; init; }

    /// <summary>Your points on this game's day board (finalized runs only) and rank there.</summary>
    public double? DayPoints { get; init; }
    public long? DayRank { get; init; }

    /// <summary>Ranked runs of this game you started today.</summary>
    public int RunsToday { get; init; }
}

public sealed class EntryAllowanceDto
{
    public int Used { get; init; }

    /// <summary>Ranked runs the player may start today (free + unlocked); null = unlimited (Plus).</summary>
    public int? Allowed { get; init; }
    public int Free { get; init; }
}

public sealed class LobbyResponse
{
    public DateTime ServerNowUtc { get; init; }
    public DateOnly UtcDate { get; init; }
    public required string WeekKey { get; init; }
    public required string MonthKey { get; init; }
    public required List<GameLobbyDto> Games { get; init; }

    /// <summary>This week's Grand Challenge (Sunday); listed all week as a preview.</summary>
    public required List<RunCardDto> Grand { get; init; }
    public bool IsGrandDay { get; init; }

    public required EntryAllowanceDto RankedEntries { get; init; }
    public long Stars { get; init; }
    public LotteryDto? Lottery { get; init; }
}

// --- Lottery ----------------------------------------------------------------------------------

public sealed class LotteryTicketDto
{
    public required string Number { get; init; }

    /// <summary>Digits matched so far, counted from the first revealed digit.</summary>
    public int Match { get; init; }

    /// <summary>Still matching every revealed digit.</summary>
    public bool Alive { get; init; }
}

public sealed class LotteryResultDto
{
    public required string Number { get; init; }

    /// <summary>With <see cref="LotteryDto.CommitHash"/>: SHA-256("{Salt}:{Number}") proves the number was fixed in advance.</summary>
    public required string Salt { get; init; }

    public int WinningMatch { get; init; }
    public int Winners { get; init; }
    public int PrizePerWinner { get; init; }

    /// <summary>True when nobody matched the first digit and the pot moved to the next day.</summary>
    public bool RolledOver { get; init; }
    public int MyPrize { get; init; }
}

public sealed class LotteryDto
{
    public required string DayKey { get; init; }
    public LotteryPhase Phase { get; init; }
    public DateTime PicksCloseAtUtc { get; init; }

    /// <summary>Next digit (null once all ten are out).</summary>
    public DateTime? NextRevealAtUtc { get; init; }
    public DateTime EndsAtUtc { get; init; }

    /// <summary>Digits revealed so far, in order.</summary>
    public required string Revealed { get; init; }

    public required string CommitHash { get; init; }
    public int Pot { get; init; }
    public int Players { get; init; }

    /// <summary>Players still matching every revealed digit.</summary>
    public int Alive { get; init; }

    public LotteryTicketDto? My { get; init; }
    public LotteryResultDto? Result { get; init; }
}

public sealed class PickLotteryRequest
{
    /// <summary>Ten digits; empty = a random "lucky dip".</summary>
    public string? Number { get; set; }
}

public enum BoardScope
{
    Global,
    Country,
    Group,
}

public sealed class BoardQuery
{
    public BoardPeriod Period { get; set; }

    /// <summary>Required for day / week / month / all-time boards (each game has its own).</summary>
    public string? GameKey { get; set; }

    /// <summary>Challenge id (run), UTC date (day), ISO week (week / grand), <c>2026-10</c> (month); empty = current.</summary>
    public string? Key { get; set; }

    public BoardScope Scope { get; set; }

    /// <summary>Country scope: defaults to the player's country.</summary>
    public string? Country { get; set; }

    public Guid? GroupId { get; set; }
    public int Limit { get; set; } = 50;
}

public sealed class BoardEntryDto
{
    public long Rank { get; init; }
    public required string DisplayName { get; init; }
    public string? CountryCode { get; init; }

    /// <summary>Points (0–1000 per round; totals for day, week, grand, all-time).</summary>
    public double Points { get; init; }

    /// <summary>Round boards: server-measured solve time.</summary>
    public long? ElapsedMs { get; init; }

    public bool IsMe { get; init; }
}

public sealed class BoardResponse
{
    public BoardPeriod Period { get; init; }
    public required string Key { get; init; }
    public BoardScope Scope { get; init; }

    /// <summary>"Germany", the group's name…</summary>
    public string? ScopeName { get; init; }

    /// <summary>The board's game (null for the Grand Challenge).</summary>
    public string? GameKey { get; init; }

    /// <summary>True once the board is closed and its points are final.</summary>
    public bool Final { get; init; }

    public long Total { get; init; }
    public required List<BoardEntryDto> Entries { get; init; }

    /// <summary>The player's own row when it is not in <see cref="Entries"/>.</summary>
    public BoardEntryDto? Me { get; init; }
}

/// <summary>Live standing right after finishing a shared challenge.</summary>
public sealed class StandingDto
{
    public long Rank { get; init; }
    public long Players { get; init; }

    /// <summary>Points if the round closed now.</summary>
    public int ProvisionalPoints { get; init; }
}

public sealed class EntryDecision
{
    public string? Error { get; init; }
    public int StatusCode { get; init; } = 400;
    public string? CountryCode { get; init; }

    public static EntryDecision Deny(string error, int statusCode) => new() { Error = error, StatusCode = statusCode };
}

// --- Groups -----------------------------------------------------------------------------------

public sealed class CreateGroupRequest
{
    public string Name { get; set; } = "";
}

public sealed class JoinGroupRequest
{
    public string Code { get; set; } = "";
}

public sealed class GroupDto
{
    public Guid GroupId { get; init; }
    public required string Name { get; init; }
    public required string InviteCode { get; init; }
    public required string InviteUrl { get; init; }
    public int MemberCount { get; init; }
    public bool IsOwner { get; init; }
}

public sealed class GroupMemberDto
{
    public required string DisplayName { get; init; }
    public string? CountryCode { get; init; }
    public bool IsOwner { get; init; }
    public bool IsMe { get; init; }
    public DateTime JoinedAtUtc { get; init; }
}

public sealed class GroupDetailDto
{
    public required GroupDto Group { get; init; }
    public required List<GroupMemberDto> Members { get; init; }
}

/// <summary>What an invite link shows before joining.</summary>
public sealed class GroupInviteDto
{
    public required string Name { get; init; }
    public int MemberCount { get; init; }
    public bool AlreadyMember { get; init; }
}

// --- Admin schedule ---------------------------------------------------------------------------

public sealed class ScheduleEntryDto
{
    public Guid ChallengeId { get; init; }
    public ChallengeKind Kind { get; init; }
    public required string SlotKey { get; init; }
    public int Sequence { get; init; }
    public required string GameKey { get; init; }
    public int Difficulty { get; init; }
    public DateTime OpensAtUtc { get; init; }
    public DateTime JoinClosesAtUtc { get; init; }
    public DateTime ClosesAtUtc { get; init; }
    public ChallengeState State { get; init; }
    public int Attempts { get; init; }
    public bool Finalized { get; init; }
}

public sealed class SwapPuzzleRequest
{
    /// <summary>Null = a different random game; the same key = a fresh puzzle of that game.</summary>
    public string? GameKey { get; set; }
}

public sealed class SetWindowRequest
{
    public DateTime OpensAtUtc { get; set; }

    /// <summary>Last moment to start (defaults to <see cref="ClosesAtUtc"/>).</summary>
    public DateTime? JoinClosesAtUtc { get; set; }

    public DateTime ClosesAtUtc { get; set; }
}

public sealed class CompetitionRunResponse
{
    public int Scheduled { get; init; }
    public int Announced { get; init; }
    public int Finalized { get; init; }
    public int PeriodsClosed { get; init; }
    public int LotteryDigits { get; init; }
    public bool LotterySettled { get; init; }
}
