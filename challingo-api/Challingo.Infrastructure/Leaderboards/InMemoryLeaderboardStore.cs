using System.Collections.Concurrent;
using Challingo.Core.DTO.Leaderboard;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Infrastructure.Leaderboards;

/// <summary>
/// Single-process fallback when Redis__Enabled=false (local dev, tests). Not shared between
/// API and Worker or between API replicas — enable Redis for anything real.
/// </summary>
public sealed class InMemoryLeaderboardStore(TimeProvider? clock = null) : ILeaderboardStore
{
    private readonly ConcurrentDictionary<string, Board> _boards = new(StringComparer.Ordinal);
    private readonly TimeProvider _clock = clock ?? TimeProvider.System;

    public Task SetScoreAsync(string board, string memberId, double score, bool onlyIfHigher = false, CancellationToken ct = default)
    {
        var b = GetOrCreate(board);
        lock (b)
        {
            if (!onlyIfHigher || !b.Scores.TryGetValue(memberId, out var current) || score > current)
                b.Scores[memberId] = score;
        }
        return Task.CompletedTask;
    }

    public Task<double> IncrementAsync(string board, string memberId, double delta, CancellationToken ct = default)
    {
        var b = GetOrCreate(board);
        lock (b)
        {
            var total = b.Scores.GetValueOrDefault(memberId) + delta;
            b.Scores[memberId] = total;
            return Task.FromResult(total);
        }
    }

    public Task<LeaderboardEntry?> GetEntryAsync(string board, string memberId, CancellationToken ct = default) =>
        Task.FromResult(Ranked(board).FirstOrDefault(e => e.MemberId == memberId));

    public Task<IReadOnlyList<LeaderboardEntry>> GetTopAsync(string board, int offset = 0, int count = 50, CancellationToken ct = default) =>
        Task.FromResult<IReadOnlyList<LeaderboardEntry>>(Ranked(board).Skip(Math.Max(0, offset)).Take(Math.Max(0, count)).ToList());

    public Task<IReadOnlyList<LeaderboardEntry>> GetAroundAsync(string board, string memberId, int radius = 5, CancellationToken ct = default)
    {
        var ranked = Ranked(board);
        var index = ranked.FindIndex(e => e.MemberId == memberId);
        if (index < 0)
            return Task.FromResult<IReadOnlyList<LeaderboardEntry>>([]);

        radius = Math.Max(0, radius);
        var start = Math.Max(0, index - radius);
        return Task.FromResult<IReadOnlyList<LeaderboardEntry>>(ranked.Skip(start).Take(index - start + radius + 1).ToList());
    }

    public Task<IReadOnlyList<LeaderboardEntry>> GetForMembersAsync(string board, IReadOnlyCollection<string> memberIds, CancellationToken ct = default)
    {
        var wanted = memberIds.ToHashSet(StringComparer.Ordinal);
        var rows = Snapshot(board).Where(kv => wanted.Contains(kv.Key)).Select(kv => (kv.Key, kv.Value));
        return Task.FromResult<IReadOnlyList<LeaderboardEntry>>(LeaderboardRanking.Rank(rows));
    }

    public Task<long> CountAsync(string board, CancellationToken ct = default) => Task.FromResult((long)Snapshot(board).Count);

    public Task RemoveAsync(string board, string memberId, CancellationToken ct = default)
    {
        if (_boards.TryGetValue(board, out var b))
        {
            lock (b)
                b.Scores.Remove(memberId);
        }
        return Task.CompletedTask;
    }

    public Task DeleteBoardAsync(string board, CancellationToken ct = default)
    {
        _boards.TryRemove(board, out _);
        return Task.CompletedTask;
    }

    public Task ExpireAsync(string board, TimeSpan ttl, CancellationToken ct = default)
    {
        if (_boards.TryGetValue(board, out var b))
        {
            lock (b)
                b.ExpiresAt = _clock.GetUtcNow() + ttl;
        }
        return Task.CompletedTask;
    }

    private List<LeaderboardEntry> Ranked(string board) =>
        LeaderboardRanking.Rank(Snapshot(board).Select(kv => (kv.Key, kv.Value)));

    private List<KeyValuePair<string, double>> Snapshot(string board)
    {
        if (!_boards.TryGetValue(board, out var b))
            return [];

        lock (b)
        {
            if (b.ExpiresAt is { } expires && expires <= _clock.GetUtcNow())
            {
                _boards.TryRemove(board, out _);
                return [];
            }
            return b.Scores.ToList();
        }
    }

    private Board GetOrCreate(string board)
    {
        Snapshot(board); // drops the board first if it has expired
        return _boards.GetOrAdd(board, _ => new Board());
    }

    private sealed class Board
    {
        public Dictionary<string, double> Scores { get; } = new(StringComparer.Ordinal);
        public DateTimeOffset? ExpiresAt { get; set; }
    }
}
