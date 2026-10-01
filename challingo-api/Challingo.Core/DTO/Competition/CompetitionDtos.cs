using Challingo.Core.Competition;
using Challingo.Core.Domain.Enums;

namespace Challingo.Core.DTO.Competition;

public enum ChallengeState
{
    Upcoming,
    Open,
    Closed,
}

/// <summary>The player's own attempt on a challenge.</summary>
public sealed class MyAttemptDto
{
    public Guid AttemptId { get; init; }
    public AttemptStatus Status { get; init; }
    public long? ElapsedMs { get; init; }

    /// <summary>Final points (null until the challenge is finalized).</summary>
    public int? Points { get; init; }
    public int? Rank { get; init; }
    public bool CountsForDay { get; init; }
}

public sealed class ChallengeCardDto
{
    public Guid ChallengeId { get; init; }
    public ChallengeKind Kind { get; init; }
    public int Sequence { get; init; }

    /// <summary>Null while the round is more than one round away (games are announced one round ahead).</summary>
    public string? GameKey { get; init; }

    public DateTime OpensAtUtc { get; init; }
    public DateTime ClosesAtUtc { get; init; }
    public ChallengeState State { get; init; }
    public bool Finalized { get; init; }
    public MyAttemptDto? My { get; init; }
}

public sealed class FeaturedGameDto
{
    public DateOnly Date { get; init; }
    public required string GameKey { get; init; }
}

public sealed class EntryAllowanceDto
{
    public int Used { get; init; }

    /// <summary>Ranked rounds the player may start today (free + unlocked).</summary>
    public int Allowed { get; init; }
    public int Free { get; init; }
}

public sealed class TodayResponse
{
    public DateTime ServerNowUtc { get; init; }
    public DateOnly UtcDate { get; init; }
    public DateOnly LocalDate { get; init; }
    public required string WeekKey { get; init; }
    public bool IsGrandDay { get; init; }

    /// <summary>Today's six ranked rounds (empty on Sunday).</summary>
    public required List<ChallengeCardDto> Rounds { get; init; }

    /// <summary>The next ranked round that is not open yet (may be tomorrow's).</summary>
    public ChallengeCardDto? NextRound { get; init; }

    /// <summary>The daily puzzle for the player's local date (none on Sunday).</summary>
    public ChallengeCardDto? Daily { get; init; }

    /// <summary>This week's Grand Challenge games (open on Sunday).</summary>
    public required List<ChallengeCardDto> Grand { get; init; }

    /// <summary>Mon–Sat featured games; together they make Sunday's Grand Challenge.</summary>
    public required List<FeaturedGameDto> Featured { get; init; }

    public required EntryAllowanceDto RankedEntries { get; init; }
    public long Stars { get; init; }
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

    /// <summary>Challenge id (round), UTC date (day), ISO week (week / grand); empty = current.</summary>
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

    /// <summary>Round boards: the game.</summary>
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
    public bool CountsForDay { get; init; }

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
    public DateOnly? LocalDate { get; init; }
    public DateTime OpensAtUtc { get; init; }
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
    public DateTime ClosesAtUtc { get; set; }
}

public sealed class CompetitionRunResponse
{
    public int Scheduled { get; init; }
    public int Announced { get; init; }
    public int Finalized { get; init; }
    public int DaysClosed { get; init; }
    public int WeeksClosed { get; init; }
}
