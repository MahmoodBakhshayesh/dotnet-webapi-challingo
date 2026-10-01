using Challingo.Core.Competition;
using Challingo.Core.Domain.Entities;

namespace Challingo.Core.Domain.RepositoryInterfaces;

/// <summary>A player's total on a period board.</summary>
public sealed record PeriodResult(Guid UserId, double Points, string? CountryCode);

public interface ICompetitionRepository
{
    // --- Schedule -----------------------------------------------------------------------------
    Task<HashSet<string>> GetExistingSlotsAsync(IReadOnlyCollection<string> slotKeys, CancellationToken ct = default);

    /// <summary>The game of the latest ranked round opening before <paramref name="beforeUtc"/>.</summary>
    Task<string?> GetPreviousRankedGameAsync(DateTime beforeUtc, CancellationToken ct = default);

    /// <summary>This week's featured games (the daily puzzles), Monday first.</summary>
    Task<List<(DateOnly Date, string GameKey)>> GetFeaturedGamesAsync(string weekKey, CancellationToken ct = default);

    /// <summary>Adds a scheduled challenge; false if its slot already exists.</summary>
    Task<bool> TryAddScheduledAsync(Puzzle puzzle, Challenge challenge, CancellationToken ct = default);

    /// <summary>Shared (non-practice) challenges whose window overlaps [from, to), puzzle loaded, by open time.</summary>
    Task<List<Challenge>> ListChallengesAsync(DateTime fromUtc, DateTime toUtc, CancellationToken ct = default);

    Task<Challenge?> GetDailyAsync(DateOnly localDate, CancellationToken ct = default);
    Task<List<Challenge>> GetGrandAsync(string weekKey, CancellationToken ct = default);
    Task<Challenge?> GetChallengeAsync(Guid challengeId, CancellationToken ct = default);
    Task<Dictionary<Guid, int>> CountAttemptsAsync(IReadOnlyCollection<Guid> challengeIds, CancellationToken ct = default);
    Task ReplacePuzzleAsync(Guid challengeId, Puzzle puzzle, CancellationToken ct = default);
    Task SetWindowAsync(Guid challengeId, DateTime opensAtUtc, DateTime closesAtUtc, CancellationToken ct = default);

    // --- Entry --------------------------------------------------------------------------------
    /// <summary>Ranked rounds the player has started on this UTC day.</summary>
    Task<int> CountRankedEntriesAsync(Guid userId, string dayKey, CancellationToken ct = default);

    Task<List<Attempt>> GetUserAttemptsAsync(Guid userId, IReadOnlyCollection<Guid> challengeIds, CancellationToken ct = default);

    /// <summary>Attempts of these players in one challenge (for board rows).</summary>
    Task<List<Attempt>> GetAttemptsForUsersAsync(Guid challengeId, IReadOnlyCollection<Guid> userIds, CancellationToken ct = default);

    // --- Closing ------------------------------------------------------------------------------
    Task<List<Challenge>> ListAnnounceDueAsync(DateTime nowUtc, CancellationToken ct = default);
    Task MarkAnnouncedAsync(Guid challengeId, DateTime nowUtc, CancellationToken ct = default);
    Task<List<Challenge>> ListFinalizeDueAsync(DateTime nowUtc, CancellationToken ct = default);

    /// <summary>Unfinished attempts of a closed challenge become Expired.</summary>
    Task ExpireOpenAttemptsAsync(Guid challengeId, DateTime nowUtc, CancellationToken ct = default);

    Task<List<ScoredAttempt>> GetScoredAttemptsAsync(Guid challengeId, CancellationToken ct = default);
    Task SaveFinalPointsAsync(IReadOnlyList<AttemptPoints> points, CancellationToken ct = default);
    Task MarkFinalizedAsync(Guid challengeId, DateTime nowUtc, CancellationToken ct = default);

    /// <summary>Days whose six ranked rounds are all finalized but the day is not closed yet.</summary>
    Task<List<string>> GetClosableDaysAsync(CancellationToken ct = default);

    /// <summary>Weeks whose Grand Challenge games are all finalized but the week is not closed yet.</summary>
    Task<List<string>> GetClosableWeeksAsync(CancellationToken ct = default);

    Task<bool> IsPeriodClosedAsync(string key, CancellationToken ct = default);
    Task MarkPeriodClosedAsync(string key, DateTime nowUtc, CancellationToken ct = default);

    /// <summary>Points of each player's first ranked round of the day.</summary>
    Task<List<PeriodResult>> GetDayResultsAsync(string dayKey, IReadOnlyCollection<Guid>? userIds = null, CancellationToken ct = default);

    /// <summary>Mon–Sat counting rounds plus the Grand Challenge, per player (country of their latest attempt).</summary>
    Task<List<PeriodResult>> GetWeekResultsAsync(string weekKey, IReadOnlyCollection<Guid>? userIds = null, CancellationToken ct = default);

    Task<List<PeriodResult>> GetGrandResultsAsync(string weekKey, IReadOnlyCollection<Guid>? userIds = null, CancellationToken ct = default);
    Task<List<PeriodResult>> GetAllTimeResultsAsync(IReadOnlyCollection<Guid> userIds, CancellationToken ct = default);

    // --- Stars --------------------------------------------------------------------------------
    /// <summary>Records an award once per (player, <paramref name="refKey"/>); false if it was already paid.</summary>
    Task<bool> TryAwardStarsAsync(Guid userId, int amount, string refKey, CancellationToken ct = default);

    Task<long> GetStarBalanceAsync(Guid userId, CancellationToken ct = default);

    // --- Players ------------------------------------------------------------------------------
    Task<Dictionary<Guid, (string DisplayName, string? CountryCode)>> GetPlayersAsync(IReadOnlyCollection<Guid> userIds, CancellationToken ct = default);
}
