using Challingo.Core.Competition;
using Challingo.Core.Domain.Entities;

namespace Challingo.Core.Domain.RepositoryInterfaces;

/// <summary>A player's total on a period board.</summary>
public sealed record PeriodResult(Guid UserId, double Points, string? CountryCode);

public interface ICompetitionRepository
{
    // --- Schedule -----------------------------------------------------------------------------
    Task<HashSet<string>> GetExistingSlotsAsync(IReadOnlyCollection<string> slotKeys, CancellationToken ct = default);

    /// <summary>Adds a scheduled challenge; false if its slot already exists.</summary>
    Task<bool> TryAddScheduledAsync(Puzzle puzzle, Challenge challenge, CancellationToken ct = default);

    /// <summary>Shared (non-practice) challenges whose window overlaps [from, to), puzzle loaded, by open time.</summary>
    Task<List<Challenge>> ListChallengesAsync(DateTime fromUtc, DateTime toUtc, CancellationToken ct = default);

    Task<List<Challenge>> GetGrandAsync(string weekKey, CancellationToken ct = default);
    Task<Challenge?> GetChallengeAsync(Guid challengeId, CancellationToken ct = default);
    Task<Dictionary<Guid, int>> CountAttemptsAsync(IReadOnlyCollection<Guid> challengeIds, CancellationToken ct = default);

    /// <summary>Points the challenge at a new puzzle (and its game).</summary>
    Task ReplacePuzzleAsync(Guid challengeId, Puzzle puzzle, CancellationToken ct = default);

    Task SetWindowAsync(Guid challengeId, DateTime opensAtUtc, DateTime joinClosesAtUtc, DateTime closesAtUtc, CancellationToken ct = default);

    // --- Entry --------------------------------------------------------------------------------
    /// <summary>Ranked runs (all games) the player has started that open on this UTC day.</summary>
    Task<int> CountRankedEntriesAsync(Guid userId, string dayKey, CancellationToken ct = default);

    /// <summary>The same, per game.</summary>
    Task<Dictionary<string, int>> CountRankedEntriesByGameAsync(Guid userId, string dayKey, CancellationToken ct = default);

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

    /// <summary>Games that had ranked runs in a day / week / month (key as on <see cref="Challenge"/>).</summary>
    Task<List<string>> GetGamesWithRunsAsync(BoardPeriod period, string key, CancellationToken ct = default);

    /// <summary>True while any ranked run of the game in that period is not finalized.</summary>
    Task<bool> HasUnfinalizedRunsAsync(string gameKey, BoardPeriod period, string key, CancellationToken ct = default);

    /// <summary>True once the week's Grand games exist and are all finalized.</summary>
    Task<bool> IsGrandFinalizedAsync(string weekKey, CancellationToken ct = default);

    Task<bool> IsPeriodClosedAsync(string key, CancellationToken ct = default);
    Task MarkPeriodClosedAsync(string key, DateTime nowUtc, CancellationToken ct = default);

    /// <summary>Sum of a game's run points per player for a day / week / month (or all time with key "all"), country of their latest run.</summary>
    Task<List<PeriodResult>> GetGameResultsAsync(string gameKey, BoardPeriod period, string key, IReadOnlyCollection<Guid>? userIds = null, CancellationToken ct = default);

    Task<List<PeriodResult>> GetGrandResultsAsync(string weekKey, IReadOnlyCollection<Guid>? userIds = null, CancellationToken ct = default);

    // --- Stars --------------------------------------------------------------------------------
    /// <summary>Records an award once per (player, <paramref name="refKey"/>); false if it was already paid.</summary>
    Task<bool> TryAwardStarsAsync(Guid userId, int amount, string refKey, CancellationToken ct = default);

    Task<long> GetStarBalanceAsync(Guid userId, CancellationToken ct = default);

    // --- Players ------------------------------------------------------------------------------
    Task<Dictionary<Guid, (string DisplayName, string? CountryCode)>> GetPlayersAsync(IReadOnlyCollection<Guid> userIds, CancellationToken ct = default);
}
