using Microsoft.Extensions.Options;
using Challingo.Core.DTO.Leaderboard;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;
using StackExchange.Redis;

namespace Challingo.Infrastructure.Leaderboards;

/// <summary>
/// Leaderboards on Redis sorted sets (keys: <c>{Redis:InstanceName}lb:{board}</c>). Needs Redis 6.2+
/// (ZADD GT still inserts new members; it only blocks lowering an existing score).
/// </summary>
public sealed class RedisLeaderboardStore(IConnectionMultiplexer redis, IOptions<RedisOptions> options) : ILeaderboardStore
{
    private IDatabase Db => redis.GetDatabase();

    private RedisKey Key(string board) => $"{options.Value.InstanceName}lb:{board}";

    public Task SetScoreAsync(string board, string memberId, double score, bool onlyIfHigher = false, CancellationToken ct = default) =>
        Db.SortedSetAddAsync(Key(board), memberId, score, onlyIfHigher ? SortedSetWhen.GreaterThan : SortedSetWhen.Always);

    public Task<double> IncrementAsync(string board, string memberId, double delta, CancellationToken ct = default) =>
        Db.SortedSetIncrementAsync(Key(board), memberId, delta);

    public async Task<LeaderboardEntry?> GetEntryAsync(string board, string memberId, CancellationToken ct = default)
    {
        var key = Key(board);
        var scoreTask = Db.SortedSetScoreAsync(key, memberId);
        var rankTask = Db.SortedSetRankAsync(key, memberId, Order.Descending);
        await Task.WhenAll(scoreTask, rankTask);
        return scoreTask.Result is { } score && rankTask.Result is { } rank
            ? new LeaderboardEntry(memberId, score, rank + 1)
            : null;
    }

    public async Task<IReadOnlyList<LeaderboardEntry>> GetTopAsync(string board, int offset = 0, int count = 50, CancellationToken ct = default)
    {
        offset = Math.Max(0, offset);
        if (count <= 0)
            return [];

        var rows = await Db.SortedSetRangeByRankWithScoresAsync(Key(board), offset, offset + count - 1, Order.Descending);
        return ToEntries(rows, offset);
    }

    public async Task<IReadOnlyList<LeaderboardEntry>> GetAroundAsync(string board, string memberId, int radius = 5, CancellationToken ct = default)
    {
        var key = Key(board);
        var rank = await Db.SortedSetRankAsync(key, memberId, Order.Descending);
        if (rank is null)
            return [];

        var start = Math.Max(0, rank.Value - Math.Max(0, radius));
        var rows = await Db.SortedSetRangeByRankWithScoresAsync(key, start, rank.Value + Math.Max(0, radius), Order.Descending);
        return ToEntries(rows, start);
    }

    public async Task<IReadOnlyList<LeaderboardEntry>> GetForMembersAsync(string board, IReadOnlyCollection<string> memberIds, CancellationToken ct = default)
    {
        if (memberIds.Count == 0)
            return [];

        var members = memberIds.Distinct().ToArray();
        var scores = await Db.SortedSetScoresAsync(Key(board), members.Select(m => (RedisValue)m).ToArray());
        return LeaderboardRanking.Rank(members.Zip(scores)
            .Where(p => p.Second.HasValue)
            .Select(p => (p.First, p.Second!.Value)));
    }

    public Task<long> CountAsync(string board, CancellationToken ct = default) => Db.SortedSetLengthAsync(Key(board));

    public Task RemoveAsync(string board, string memberId, CancellationToken ct = default) => Db.SortedSetRemoveAsync(Key(board), memberId);

    public Task DeleteBoardAsync(string board, CancellationToken ct = default) => Db.KeyDeleteAsync(Key(board));

    public Task ExpireAsync(string board, TimeSpan ttl, CancellationToken ct = default) => Db.KeyExpireAsync(Key(board), ttl);

    private static List<LeaderboardEntry> ToEntries(SortedSetEntry[] rows, long startRank) =>
        rows.Select((row, i) => new LeaderboardEntry(row.Element.ToString(), row.Score, startRank + i + 1)).ToList();
}

internal static class LeaderboardRanking
{
    /// <summary>Same order as Redis ZREVRANGE: score desc, then member desc (ordinal) on ties.</summary>
    public static List<LeaderboardEntry> Rank(IEnumerable<(string Member, double Score)> rows) =>
        rows.OrderByDescending(r => r.Score)
            .ThenByDescending(r => r.Member, StringComparer.Ordinal)
            .Select((r, i) => new LeaderboardEntry(r.Member, r.Score, i + 1))
            .ToList();
}
