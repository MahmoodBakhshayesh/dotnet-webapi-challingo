using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Challingo.Core.Competition;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.Enums;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.Competition;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services;

/// <summary>
/// Runs every minute in the Worker. Every step can run again safely: points are recomputed from Postgres,
/// boards are set (not incremented) from Postgres totals, and each star award has a unique reference.
/// </summary>
public sealed class CompetitionCloser(
    ICompetitionRepository competition,
    ILeaderboardStore boards,
    IRealtimeNotifier realtime,
    IOptions<CompetitionOptions> options,
    ILogger<CompetitionCloser> logger) : ICompetitionCloser
{
    private static readonly TimeSpan RoundBoardTtl = TimeSpan.FromDays(14);
    private static readonly TimeSpan DayBoardTtl = TimeSpan.FromDays(35);
    private static readonly TimeSpan WeekBoardTtl = TimeSpan.FromDays(120);

    public async Task<CompetitionRunResponse> RunAsync(DateTime nowUtc, CancellationToken ct = default)
    {
        var announced = 0;
        foreach (var challenge in await competition.ListAnnounceDueAsync(nowUtc, ct))
        {
            await realtime.ToAllAsync("round.opened", new
            {
                challengeId = challenge.Id,
                kind = challenge.Kind,
                sequence = challenge.Sequence,
                gameKey = challenge.Puzzle?.GameKey,
                closesAtUtc = challenge.ClosesAtUtc,
            }, ct);
            await competition.MarkAnnouncedAsync(challenge.Id, nowUtc, ct);
            announced++;
        }

        var finalized = 0;
        foreach (var challenge in await competition.ListFinalizeDueAsync(nowUtc, ct))
        {
            await FinalizeAsync(challenge, nowUtc, ct);
            finalized++;
        }

        var daysClosed = 0;
        foreach (var day in await competition.GetClosableDaysAsync(ct))
        {
            await CloseDayAsync(day, nowUtc, ct);
            daysClosed++;
        }

        var weeksClosed = 0;
        foreach (var week in await competition.GetClosableWeeksAsync(ct))
        {
            await CloseWeekAsync(week, nowUtc, ct);
            weeksClosed++;
        }

        return new CompetitionRunResponse
        {
            Announced = announced,
            Finalized = finalized,
            DaysClosed = daysClosed,
            WeeksClosed = weeksClosed,
        };
    }

    private async Task FinalizeAsync(Challenge challenge, DateTime nowUtc, CancellationToken ct)
    {
        await competition.ExpireOpenAttemptsAsync(challenge.Id, nowUtc, ct);
        var attempts = await competition.GetScoredAttemptsAsync(challenge.Id, ct);
        var gameKey = challenge.Puzzle?.GameKey ?? "";
        var points = PointsCalculator.Assign(gameKey, attempts, options.Value.SmallRoundThreshold);
        await competition.SaveFinalPointsAsync(points, ct);

        if (challenge.Kind == ChallengeKind.Ranked)
        {
            var finishers = points.Where(p => p.RankScore is not null).ToList();
            await PayAsync(finishers, p => p.UserId, p => p.RankScore!.Value, p => p.CountryCode,
                BoardPeriod.Round, $"round:{challenge.Id:N}", ct);
            await UpdatePeriodBoardsAsync(challenge, attempts, ct);
        }

        await competition.MarkFinalizedAsync(challenge.Id, nowUtc, ct);
        await boards.ExpireAsync(BoardKeys.Round(challenge.Id), RoundBoardTtl, ct);
        await realtime.ToGroupAsync(BoardKeys.Topic(challenge.Id), "round.finalized", new { challengeId = challenge.Id }, ct);
        logger.LogInformation("Finalized {Kind} {Slot}: {Players} players", challenge.Kind, challenge.SlotKey, points.Count);
    }

    /// <summary>Day, week and all-time boards for the players whose first ranked round of the day this was.</summary>
    private async Task UpdatePeriodBoardsAsync(Challenge challenge, IReadOnlyList<ScoredAttempt> attempts, CancellationToken ct)
    {
        var counting = await competition.GetDayResultsAsync(challenge.PeriodKey!, attempts.Select(a => a.UserId).ToList(), ct);
        if (counting.Count == 0)
            return;
        var ids = counting.Select(c => c.UserId).ToList();

        await SetAllAsync(counting, key => BoardKeys.Day(challenge.PeriodKey!, key), ct);
        await SetAllAsync(await competition.GetWeekResultsAsync(challenge.WeekKey!, ids, ct), key => BoardKeys.Week(challenge.WeekKey!, key), ct);
        await SetAllAsync(await competition.GetAllTimeResultsAsync(ids, ct), BoardKeys.AllTime, ct);

        await boards.ExpireAsync(BoardKeys.Day(challenge.PeriodKey!), DayBoardTtl, ct);
        await boards.ExpireAsync(BoardKeys.Week(challenge.WeekKey!), WeekBoardTtl, ct);
    }

    private async Task CloseDayAsync(string dayKey, DateTime nowUtc, CancellationToken ct)
    {
        var results = await competition.GetDayResultsAsync(dayKey, null, ct);
        await PayAsync(results, r => r.UserId, r => r.Points, r => r.CountryCode, BoardPeriod.Day, $"day:{dayKey}", ct);
        await competition.MarkPeriodClosedAsync($"day:{dayKey}", nowUtc, ct);
        await realtime.ToAllAsync("day.closed", new { dayKey }, ct);
        logger.LogInformation("Closed day {Day}: {Players} players", dayKey, results.Count);
    }

    private async Task CloseWeekAsync(string weekKey, DateTime nowUtc, CancellationToken ct)
    {
        // Grand board: replace the live par points with the final percentile totals.
        var grand = await competition.GetGrandResultsAsync(weekKey, null, ct);
        await SetAllAsync(grand, key => BoardKeys.Grand(weekKey, key), ct);
        await PayAsync(grand, r => r.UserId, r => r.Points, r => r.CountryCode, BoardPeriod.Grand, $"grand:{weekKey}", ct);

        var week = await competition.GetWeekResultsAsync(weekKey, null, ct);
        await SetAllAsync(week, key => BoardKeys.Week(weekKey, key), ct);
        await SetAllAsync(await competition.GetAllTimeResultsAsync(grand.Select(g => g.UserId).ToList(), ct), BoardKeys.AllTime, ct);
        await PayAsync(week, r => r.UserId, r => r.Points, r => r.CountryCode, BoardPeriod.Week, $"week:{weekKey}", ct);

        await competition.MarkPeriodClosedAsync($"week:{weekKey}", nowUtc, ct);
        await boards.ExpireAsync(BoardKeys.Grand(weekKey), WeekBoardTtl, ct);
        await realtime.ToAllAsync("week.closed", new { weekKey }, ct);
        logger.LogInformation("Closed week {Week}: {Players} players, {Grand} in the Grand Challenge", weekKey, week.Count, grand.Count);
    }

    private async Task SetAllAsync(IReadOnlyList<PeriodResult> results, Func<string?, string> boardFor, CancellationToken ct)
    {
        foreach (var r in results)
        {
            var member = r.UserId.ToString();
            await boards.SetScoreAsync(boardFor(null), member, r.Points, ct: ct);
            if (r.CountryCode is { } country)
                await boards.SetScoreAsync(boardFor(country), member, r.Points, ct: ct);
        }
    }

    /// <summary>Stars for the global podium and each country's podium.</summary>
    private async Task PayAsync<T>(
        IReadOnlyList<T> items, Func<T, Guid> user, Func<T, double> score, Func<T, string?> country,
        BoardPeriod period, string refPrefix, CancellationToken ct)
    {
        foreach (var (item, place) in StarRewards.Podium(items, score))
            await AwardAsync(user(item), StarRewards.For(period, true, place), $"{refPrefix}:g", period, place, null, ct);

        foreach (var byCountry in items.Where(i => country(i) is not null).GroupBy(country))
        {
            foreach (var (item, place) in StarRewards.Podium(byCountry, score))
                await AwardAsync(user(item), StarRewards.For(period, false, place), $"{refPrefix}:cc", period, place, byCountry.Key, ct);
        }
    }

    private async Task AwardAsync(Guid userId, int amount, string refKey, BoardPeriod period, int place, string? country, CancellationToken ct)
    {
        if (amount <= 0 || !await competition.TryAwardStarsAsync(userId, amount, refKey, ct))
            return;
        await realtime.ToUserAsync(userId.ToString(), "stars.awarded", new { amount, period, place, country, refKey }, ct);
    }
}
