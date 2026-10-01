using Challingo.Core.DTO.Leaderboard;

namespace Challingo.Core.ServiceInterfaces;

/// <summary>
/// Ranked score boards (Redis sorted sets when Redis__Enabled=true, in-memory otherwise).
/// Higher score ranks first. Board keys are free-form, e.g. <c>daily:2026-10-01</c>, <c>challenge:{id}</c>.
/// Postgres stays the source of truth — snapshot boards there when a period closes.
/// </summary>
public interface ILeaderboardStore
{
    /// <summary>Sets the score. With <paramref name="onlyIfHigher"/>, keeps the member's best score.</summary>
    Task SetScoreAsync(string board, string memberId, double score, bool onlyIfHigher = false, CancellationToken ct = default);

    /// <summary>Adds <paramref name="delta"/> to the member's score and returns the new total.</summary>
    Task<double> IncrementAsync(string board, string memberId, double delta, CancellationToken ct = default);

    Task<LeaderboardEntry?> GetEntryAsync(string board, string memberId, CancellationToken ct = default);

    /// <summary>Entries ordered by rank, starting at 0-based <paramref name="offset"/>.</summary>
    Task<IReadOnlyList<LeaderboardEntry>> GetTopAsync(string board, int offset = 0, int count = 50, CancellationToken ct = default);

    /// <summary>The member plus up to <paramref name="radius"/> neighbours above and below.</summary>
    Task<IReadOnlyList<LeaderboardEntry>> GetAroundAsync(string board, string memberId, int radius = 5, CancellationToken ct = default);

    /// <summary>Ranks only the given members (e.g. a friends board) against each other.</summary>
    Task<IReadOnlyList<LeaderboardEntry>> GetForMembersAsync(string board, IReadOnlyCollection<string> memberIds, CancellationToken ct = default);

    Task<long> CountAsync(string board, CancellationToken ct = default);
    Task RemoveAsync(string board, string memberId, CancellationToken ct = default);
    Task DeleteBoardAsync(string board, CancellationToken ct = default);

    /// <summary>Lets finished boards expire (e.g. 30 days after a daily board closes).</summary>
    Task ExpireAsync(string board, TimeSpan ttl, CancellationToken ct = default);
}
