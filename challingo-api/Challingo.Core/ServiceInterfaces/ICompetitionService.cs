using Microsoft.AspNetCore.Mvc;
using Challingo.Core.Domain.Entities;
using Challingo.Core.DTO.Competition;

namespace Challingo.Core.ServiceInterfaces;

public interface ICompetitionService
{
    /// <summary>Who may start a shared challenge: daily = own local date, ranked = within today's allowance.</summary>
    Task<EntryDecision> CheckEntryAsync(Guid userId, Challenge challenge, DateTime nowUtc);

    /// <summary>Puts a finished attempt on the live boards and returns the player's standing.</summary>
    Task<StandingDto?> OnAttemptCompletedAsync(Attempt attempt, Challenge challenge);

    /// <summary>Every game's current and next run, the Grand Challenge, entries, stars and the lottery.</summary>
    Task<ActionResult<LobbyResponse>> GetLobbyAsync(Guid userId);
    Task<ActionResult<BoardResponse>> GetBoardAsync(Guid userId, BoardQuery query);
}

public interface ICompetitionScheduler
{
    /// <summary>Creates any missing challenges for the coming days; safe to run any number of times.</summary>
    Task<int> EnsureScheduleAsync(DateTime nowUtc, CancellationToken ct = default);
}

public interface ICompetitionCloser
{
    /// <summary>Announces opened rounds, finalizes closed ones, closes finished days and weeks and pays stars.</summary>
    Task<CompetitionRunResponse> RunAsync(DateTime nowUtc, CancellationToken ct = default);
}

public interface ILotteryService
{
    Task<LotteryDto?> GetTodayAsync(Guid userId);
    Task<ActionResult<LotteryDto>> GetTodayResultAsync(Guid userId);
    Task<ActionResult<LotteryDto>> PickAsync(Guid userId, PickLotteryRequest request);
    Task<ActionResult<List<LotteryDto>>> GetHistoryAsync(Guid userId);

    /// <summary>Creates today's and tomorrow's draws (number fixed and committed in advance).</summary>
    Task<int> EnsureDrawsAsync(DateTime nowUtc, CancellationToken ct = default);

    /// <summary>Announces newly revealed digits and settles finished draws. Returns (digits announced, settled).</summary>
    Task<(int Digits, bool Settled)> RunAsync(DateTime nowUtc, CancellationToken ct = default);
}

public interface IScheduleAdminService
{
    Task<ActionResult<List<ScheduleEntryDto>>> ListAsync(DateTime fromUtc, DateTime toUtc);
    Task<ActionResult<ScheduleEntryDto>> SwapAsync(Guid challengeId, SwapPuzzleRequest request);
    Task<ActionResult<ScheduleEntryDto>> SetWindowAsync(Guid challengeId, SetWindowRequest request);
    Task<ActionResult<CompetitionRunResponse>> RunNowAsync();
}

public interface IGroupService
{
    Task<ActionResult<List<GroupDto>>> ListAsync(Guid userId);
    Task<ActionResult<GroupDto>> CreateAsync(Guid userId, CreateGroupRequest request);
    Task<ActionResult<GroupInviteDto>> PreviewInviteAsync(Guid userId, string code);
    Task<ActionResult<GroupDto>> JoinAsync(Guid userId, JoinGroupRequest request);
    Task<ActionResult<GroupDetailDto>> GetAsync(Guid userId, Guid groupId);
    Task<ActionResult> LeaveAsync(Guid userId, Guid groupId);
}
