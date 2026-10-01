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
    ILotteryService lottery,
    ILeaderboardStore boards,
    IRealtimeNotifier realtime,
    IOptions<CompetitionOptions> options,
    ILogger<CompetitionCloser> logger) : ICompetitionCloser
{
    private static readonly TimeSpan RunBoardTtl = TimeSpan.FromDays(7);
    private static readonly TimeSpan DayBoardTtl = TimeSpan.FromDays(35);
    private static readonly TimeSpan WeekBoardTtl = TimeSpan.FromDays(120);
    private static readonly TimeSpan MonthBoardTtl = TimeSpan.FromDays(400);

    private CompetitionOptions Options => options.Value;

    public async Task<CompetitionRunResponse> RunAsync(DateTime nowUtc, CancellationToken ct = default)
    {
        var announced = 0;
        foreach (var challenge in await competition.ListAnnounceDueAsync(nowUtc, ct))
        {
            await realtime.ToAllAsync("run.opened", new
            {
                challengeId = challenge.Id,
                kind = challenge.Kind,
                gameKey = challenge.GameKey,
                joinClosesAtUtc = challenge.JoinClosesAtUtc,
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

        var closed = await ClosePeriodsAsync(nowUtc, ct);

        await lottery.EnsureDrawsAsync(nowUtc, ct);
        var (digits, settled) = await lottery.RunAsync(nowUtc, ct);

        return new CompetitionRunResponse
        {
            Announced = announced,
            Finalized = finalized,
            PeriodsClosed = closed,
            LotteryDigits = digits,
            LotterySettled = settled,
        };
    }

    private async Task FinalizeAsync(Challenge challenge, DateTime nowUtc, CancellationToken ct)
    {
        await competition.ExpireOpenAttemptsAsync(challenge.Id, nowUtc, ct);
        var attempts = await competition.GetScoredAttemptsAsync(challenge.Id, ct);
        var points = PointsCalculator.Assign(challenge.GameKey, attempts, Options.SmallRoundThreshold);
        await competition.SaveFinalPointsAsync(points, ct);

        if (challenge.Kind == ChallengeKind.Ranked && attempts.Count > 0)
            await UpdateGameBoardsAsync(challenge, attempts.Select(a => a.UserId).Distinct().ToList(), ct);

        await competition.MarkFinalizedAsync(challenge.Id, nowUtc, ct);
        await boards.ExpireAsync(BoardKeys.Run(challenge.Id), RunBoardTtl, ct);
        await realtime.ToGroupAsync(BoardKeys.Topic(challenge.Id), "round.finalized", new { challengeId = challenge.Id }, ct);
        logger.LogInformation("Finalized {Slot}: {Players} players", challenge.SlotKey, points.Count);
    }

    /// <summary>The game's day, week, month and all-time totals for this run's players (sum of their run points).</summary>
    private async Task UpdateGameBoardsAsync(Challenge run, IReadOnlyList<Guid> players, CancellationToken ct)
    {
        foreach (var (period, key, ttl) in new (BoardPeriod, string, TimeSpan?)[]
                 {
                     (BoardPeriod.Day, run.PeriodKey!, DayBoardTtl),
                     (BoardPeriod.Week, run.WeekKey!, WeekBoardTtl),
                     (BoardPeriod.Month, run.MonthKey!, MonthBoardTtl),
                     (BoardPeriod.AllTime, BoardKeys.AllTimeKey, null),
                 })
        {
            var results = await competition.GetGameResultsAsync(run.GameKey, period, key, players, ct);
            await SetAllAsync(results, country => BoardKeys.Game(run.GameKey, period, key, country), ct);
            if (ttl is { } t)
                await boards.ExpireAsync(BoardKeys.Game(run.GameKey, period, key), t, ct);
        }
    }

    /// <summary>Closes finished days, weeks and months per game (podium stars) and finished Grand Challenges.</summary>
    private async Task<int> ClosePeriodsAsync(DateTime nowUtc, CancellationToken ct)
    {
        var today = CompetitionCalendar.UtcDate(nowUtc);
        var candidates = new List<(BoardPeriod Period, string Key)>();
        for (var d = 1; d <= 3; d++)
            candidates.Add((BoardPeriod.Day, CompetitionCalendar.DayKey(today.AddDays(-d))));
        var thisWeekStart = CompetitionCalendar.WeekStart(today);
        for (var w = 1; w <= 2; w++)
            candidates.Add((BoardPeriod.Week, CompetitionCalendar.WeekKey(thisWeekStart.AddDays(-7 * w))));
        var thisMonth = new DateOnly(today.Year, today.Month, 1);
        for (var m = 1; m <= 2; m++)
            candidates.Add((BoardPeriod.Month, CompetitionCalendar.MonthKey(thisMonth.AddMonths(-m))));

        var closed = 0;
        foreach (var (period, key) in candidates)
        {
            foreach (var game in await competition.GetGamesWithRunsAsync(period, key, ct))
            {
                var closeKey = $"{period.ToString().ToLowerInvariant()}:{game}:{key}";
                if (await competition.IsPeriodClosedAsync(closeKey, ct) || await competition.HasUnfinalizedRunsAsync(game, period, key, ct))
                    continue;
                var results = await competition.GetGameResultsAsync(game, period, key, null, ct);
                await PayAsync(results, period, closeKey, game, ct);
                await competition.MarkPeriodClosedAsync(closeKey, nowUtc, ct);
                await realtime.ToAllAsync("board.closed", new { period, gameKey = game, key }, ct);
                closed++;
            }
        }

        // Grand Challenge: this week's (once Sunday is over) and last week's.
        foreach (var weekKey in new[] { CompetitionCalendar.WeekKey(today), CompetitionCalendar.WeekKey(today.AddDays(-7)) }.Distinct())
        {
            var closeKey = $"grand:{weekKey}";
            if (await competition.IsPeriodClosedAsync(closeKey, ct) || !await competition.IsGrandFinalizedAsync(weekKey, ct))
                continue;
            // Replace the live par points with the final percentile totals.
            var grand = await competition.GetGrandResultsAsync(weekKey, null, ct);
            await SetAllAsync(grand, country => BoardKeys.Grand(weekKey, country), ct);
            await boards.ExpireAsync(BoardKeys.Grand(weekKey), WeekBoardTtl, ct);
            await PayAsync(grand, BoardPeriod.Grand, closeKey, null, ct);
            await competition.MarkPeriodClosedAsync(closeKey, nowUtc, ct);
            await realtime.ToAllAsync("board.closed", new { period = BoardPeriod.Grand, key = weekKey }, ct);
            closed++;
        }
        return closed;
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
    private async Task PayAsync(IReadOnlyList<PeriodResult> results, BoardPeriod period, string refPrefix, string? gameKey, CancellationToken ct)
    {
        foreach (var (item, place) in StarRewards.Podium(results, r => r.Points))
            await AwardAsync(item.UserId, StarRewards.For(Options.Stars, period, true, place), $"{refPrefix}:g", period, place, null, gameKey, ct);

        foreach (var byCountry in results.Where(r => r.CountryCode is not null).GroupBy(r => r.CountryCode))
        {
            foreach (var (item, place) in StarRewards.Podium(byCountry, r => r.Points))
                await AwardAsync(item.UserId, StarRewards.For(Options.Stars, period, false, place), $"{refPrefix}:cc", period, place, byCountry.Key, gameKey, ct);
        }
    }

    private async Task AwardAsync(Guid userId, int amount, string refKey, BoardPeriod period, int place, string? country, string? gameKey, CancellationToken ct)
    {
        if (amount <= 0 || !await competition.TryAwardStarsAsync(userId, amount, refKey, ct))
            return;
        await realtime.ToUserAsync(userId.ToString(), "stars.awarded", new { amount, period, place, country, gameKey, refKey }, ct);
    }
}
