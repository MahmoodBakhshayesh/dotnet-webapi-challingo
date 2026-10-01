using Microsoft.Extensions.Time.Testing;
using Challingo.Infrastructure.Leaderboards;
using Xunit;

namespace Challingo.Tests;

public class InMemoryLeaderboardStoreTests
{
    private const string Board = "daily:2026-10-01";

    [Fact]
    public async Task Ranks_highest_score_first()
    {
        var store = new InMemoryLeaderboardStore();
        await store.SetScoreAsync(Board, "ana", 120);
        await store.SetScoreAsync(Board, "ben", 300);
        await store.SetScoreAsync(Board, "cy", 50);

        var top = await store.GetTopAsync(Board);

        Assert.Equal(["ben", "ana", "cy"], top.Select(e => e.MemberId));
        Assert.Equal([1L, 2L, 3L], top.Select(e => e.Rank));
        Assert.Equal(2, (await store.GetEntryAsync(Board, "ana"))!.Rank);
    }

    [Fact]
    public async Task OnlyIfHigher_keeps_best_score_but_adds_new_members()
    {
        var store = new InMemoryLeaderboardStore();
        await store.SetScoreAsync(Board, "ana", 200, onlyIfHigher: true);
        await store.SetScoreAsync(Board, "ana", 150, onlyIfHigher: true);
        await store.SetScoreAsync(Board, "ana", 250, onlyIfHigher: true);

        Assert.Equal(250, (await store.GetEntryAsync(Board, "ana"))!.Score);
    }

    [Fact]
    public async Task Increment_accumulates()
    {
        var store = new InMemoryLeaderboardStore();
        await store.IncrementAsync("weekly", "ana", 10);
        var total = await store.IncrementAsync("weekly", "ana", 5);

        Assert.Equal(15, total);
    }

    [Fact]
    public async Task Around_returns_neighbours_clamped_at_top()
    {
        var store = new InMemoryLeaderboardStore();
        for (var i = 1; i <= 10; i++)
            await store.SetScoreAsync(Board, $"p{i:00}", i * 10);

        var aroundSecond = await store.GetAroundAsync(Board, "p09", radius: 2);
        Assert.Equal(["p10", "p09", "p08", "p07"], aroundSecond.Select(e => e.MemberId));

        var aroundMiddle = await store.GetAroundAsync(Board, "p05", radius: 1);
        Assert.Equal([5L, 6L, 7L], aroundMiddle.Select(e => e.Rank));
    }

    [Fact]
    public async Task Members_board_ranks_only_requested_members()
    {
        var store = new InMemoryLeaderboardStore();
        await store.SetScoreAsync(Board, "ana", 100);
        await store.SetScoreAsync(Board, "ben", 300);
        await store.SetScoreAsync(Board, "cy", 200);

        var friends = await store.GetForMembersAsync(Board, ["ana", "cy", "nobody"]);

        Assert.Equal(["cy", "ana"], friends.Select(e => e.MemberId));
        Assert.Equal([1L, 2L], friends.Select(e => e.Rank));
    }

    [Fact]
    public async Task Expired_board_is_empty()
    {
        var clock = new FakeTimeProvider(DateTimeOffset.Parse("2026-10-01T00:00:00Z"));
        var store = new InMemoryLeaderboardStore(clock);
        await store.SetScoreAsync(Board, "ana", 100);
        await store.ExpireAsync(Board, TimeSpan.FromHours(1));

        clock.Advance(TimeSpan.FromMinutes(59));
        Assert.Equal(1, await store.CountAsync(Board));

        clock.Advance(TimeSpan.FromMinutes(2));
        Assert.Equal(0, await store.CountAsync(Board));
    }
}
