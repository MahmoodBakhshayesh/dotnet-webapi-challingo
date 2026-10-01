using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Challingo.Core.Competition;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.Enums;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.Competition;
using Challingo.Core.DTO.Leaderboard;
using Challingo.Core.Players;
using Challingo.Core.Puzzles;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services;

/// <summary>Entry rules, live boards and the player's lobby (every game's runs, Grand, lottery).</summary>
public sealed class CompetitionService(
    ICompetitionRepository competition,
    IPlayerProfileRepository profiles,
    IGroupRepository groups,
    IPuzzleGameRegistry games,
    ILotteryService lottery,
    IMonetizationService monetization,
    ILeaderboardStore boards,
    IRealtimeNotifier realtime,
    IOptions<CompetitionOptions> options,
    IOptions<MonetizationOptions> monetizationOptions,
    TimeProvider clock) : ICompetitionService
{
    private CompetitionOptions Options => options.Value;

    public async Task<EntryDecision> CheckEntryAsync(Guid userId, Challenge challenge, DateTime nowUtc)
    {
        var profile = await profiles.GetByUserIdAsync(userId);
        if (profile is null)
            return EntryDecision.Deny("Player profile not found.", 404);
        if (nowUtc >= challenge.JoinClosesAtUtc)
            return EntryDecision.Deny("This run is closed to new players. The next one starts soon.", 410);

        var country = PlayerTimeZones.CountryFor(PlayerProfileRules.EffectiveTimeZone(profile, nowUtc));
        if (challenge.Kind == ChallengeKind.Ranked
            && await AllowedRankedRunsAsync(userId) is { } allowed
            && await competition.CountRankedEntriesAsync(userId, challenge.PeriodKey!) >= allowed)
        {
            return EntryDecision.Deny("You have used today's runs. Watch an ad or go Plus to play more.", 402);
        }
        return new EntryDecision { CountryCode = country };
    }

    /// <summary>Free runs plus runs from today's rewarded ads; null (unlimited) with Plus.</summary>
    private async Task<int?> AllowedRankedRunsAsync(Guid userId) =>
        await monetization.IsPlusAsync(userId)
            ? null
            : Options.FreeRankedRunsPerDay + await monetization.AdsTodayAsync(userId) * monetizationOptions.Value.RunsPerAd;

    public async Task<StandingDto?> OnAttemptCompletedAsync(Attempt attempt, Challenge challenge)
    {
        if (challenge.Kind == ChallengeKind.Practice || attempt.RankScore is not { } score)
            return null;

        var member = attempt.UserId.ToString();
        await boards.SetScoreAsync(BoardKeys.Run(challenge.Id), member, score);
        if (attempt.CountryCode is { } country)
            await boards.SetScoreAsync(BoardKeys.Run(challenge.Id, country), member, score);

        if (challenge.Kind == ChallengeKind.Grand && challenge.WeekKey is { } week)
        {
            // Live Grand board: par points until Sunday ends and percentiles are known.
            var par = PointsCalculator.ParPoints(challenge.GameKey, attempt.Status, attempt.ElapsedMs, attempt.ResultJson);
            await boards.IncrementAsync(BoardKeys.Grand(week), member, par);
            if (attempt.CountryCode is { } grandCountry)
                await boards.IncrementAsync(BoardKeys.Grand(week, grandCountry), member, par);
            await realtime.ToGroupAsync(BoardKeys.GrandTopic(week), "board.changed", new { period = BoardPeriod.Grand, key = week });
        }

        var entry = await boards.GetEntryAsync(BoardKeys.Run(challenge.Id), member);
        var players = await boards.CountAsync(BoardKeys.Run(challenge.Id));
        await realtime.ToGroupAsync(BoardKeys.Topic(challenge.Id), "board.changed", new { challengeId = challenge.Id, players });

        var rank = entry?.Rank ?? players;
        return new StandingDto
        {
            Rank = rank,
            Players = players,
            ProvisionalPoints = ProvisionalPoints(challenge.GameKey, rank, players, attempt),
        };
    }

    private int ProvisionalPoints(string gameKey, long rank, long players, Attempt attempt) =>
        players >= Options.SmallRoundThreshold
            ? PointsCalculator.Percentile(rank, players)
            : PointsCalculator.ParPoints(gameKey, attempt.Status, attempt.ElapsedMs, attempt.ResultJson);

    public async Task<ActionResult<LobbyResponse>> GetLobbyAsync(Guid userId)
    {
        if (await profiles.GetByUserIdAsync(userId) is null)
            return AppResponse.NotFound("Player profile not found.");

        var now = clock.GetUtcNow().UtcDateTime;
        var today = CompetitionCalendar.UtcDate(now);
        var dayKey = CompetitionCalendar.DayKey(today);
        var weekKey = CompetitionCalendar.WeekKey(today);

        // Runs open now and the next one per game: the longest timer is a few hours.
        var window = (await competition.ListChallengesAsync(now.AddMinutes(-1), now.AddHours(6)))
            .Where(c => c.Kind == ChallengeKind.Ranked).ToList();
        var grand = await competition.GetGrandAsync(weekKey);
        var shown = window.Concat(grand).Select(c => c.Id).ToList();
        var mine = (await competition.GetUserAttemptsAsync(userId, shown)).ToDictionary(a => a.ChallengeId);
        var runsToday = await competition.CountRankedEntriesByGameAsync(userId, dayKey);
        var member = userId.ToString();

        var lobby = new List<GameLobbyDto>();
        foreach (var gameKey in games.Keys.Order())
        {
            if (RunTimetable.For(gameKey, Options) is not { } run)
                continue;
            var runs = window.Where(c => c.GameKey == gameKey).OrderBy(c => c.OpensAtUtc).ToList();
            var current = runs.FirstOrDefault(c => c.OpensAtUtc <= now && now < c.JoinClosesAtUtc);
            var next = runs.FirstOrDefault(c => c.OpensAtUtc > now);
            var day = await boards.GetEntryAsync(BoardKeys.Game(gameKey, BoardPeriod.Day, dayKey), member);
            lobby.Add(new GameLobbyDto
            {
                GameKey = gameKey,
                EveryMinutes = (int)run.Every.TotalMinutes,
                Current = current is null ? null : Card(current, now, mine),
                Next = next is null ? null : Card(next, now, mine),
                DayPoints = day?.Score,
                DayRank = day?.Rank,
                RunsToday = runsToday.GetValueOrDefault(gameKey),
            });
        }

        var allowed = await AllowedRankedRunsAsync(userId);
        return AppResponse.Ok(new LobbyResponse
        {
            ServerNowUtc = now,
            UtcDate = today,
            WeekKey = weekKey,
            MonthKey = CompetitionCalendar.MonthKey(today),
            Games = lobby,
            Grand = grand.Select(c => Card(c, now, mine)).ToList(),
            IsGrandDay = CompetitionCalendar.IsGrandDay(today),
            RankedEntries = new EntryAllowanceDto
            {
                Used = runsToday.Values.Sum(),
                Allowed = allowed,
                Free = Options.FreeRankedRunsPerDay,
                AdsToday = await monetization.AdsTodayAsync(userId),
                AdsPerDay = monetizationOptions.Value.AdsPerDay,
                Plus = allowed is null,
            },
            Stars = await competition.GetStarBalanceAsync(userId),
            Lottery = await lottery.GetTodayAsync(userId),
        });
    }

    internal static ChallengeState StateAt(Challenge c, DateTime now) =>
        now < c.OpensAtUtc ? ChallengeState.Upcoming : now < c.JoinClosesAtUtc ? ChallengeState.Open : ChallengeState.Closed;

    internal static RunCardDto Card(Challenge c, DateTime now, IReadOnlyDictionary<Guid, Attempt> mine)
    {
        mine.TryGetValue(c.Id, out var attempt);
        return new RunCardDto
        {
            ChallengeId = c.Id,
            Kind = c.Kind,
            GameKey = c.GameKey,
            Sequence = c.Sequence,
            OpensAtUtc = c.OpensAtUtc,
            JoinClosesAtUtc = c.JoinClosesAtUtc,
            ClosesAtUtc = c.ClosesAtUtc,
            State = StateAt(c, now),
            Finalized = c.FinalizedAtUtc is not null,
            My = attempt is null ? null : new MyAttemptDto
            {
                AttemptId = attempt.Id,
                Status = attempt.Status,
                ElapsedMs = attempt.ElapsedMs,
                Points = attempt.Points,
                Rank = attempt.Rank,
            },
        };
    }

    /// <summary>"Germany" for DE; the code itself when the platform has no name for it.</summary>
    internal static string CountryName(string code)
    {
        try
        {
            return new System.Globalization.RegionInfo(code).EnglishName;
        }
        catch (ArgumentException)
        {
            return code;
        }
    }

    public async Task<ActionResult<BoardResponse>> GetBoardAsync(Guid userId, BoardQuery query)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var today = CompetitionCalendar.UtcDate(now);
        var limit = Math.Clamp(query.Limit, 1, 100);
        var me = userId.ToString();

        // Resolve the board.
        Challenge? challenge = null;
        string key;
        string? gameKey = null;
        bool final;
        switch (query.Period)
        {
            case BoardPeriod.Round:
                if (!Guid.TryParse(query.Key, out var challengeId)
                    || (challenge = await competition.GetChallengeAsync(challengeId)) is null
                    || challenge.Kind == ChallengeKind.Practice)
                    return AppResponse.NotFound("Run not found.");
                key = challenge.Id.ToString();
                gameKey = challenge.GameKey;
                final = challenge.FinalizedAtUtc is not null;
                break;
            case BoardPeriod.Grand:
                key = string.IsNullOrWhiteSpace(query.Key) ? CompetitionCalendar.WeekKey(today) : query.Key.Trim();
                final = await competition.IsPeriodClosedAsync($"grand:{key}");
                break;
            default:
                gameKey = query.GameKey?.Trim().ToLowerInvariant();
                if (string.IsNullOrEmpty(gameKey) || games.Find(gameKey) is null)
                    return AppResponse.RequestError("Pick a game for this board.");
                key = query.Period switch
                {
                    _ when !string.IsNullOrWhiteSpace(query.Key) && query.Period != BoardPeriod.AllTime => query.Key.Trim(),
                    BoardPeriod.Day => CompetitionCalendar.DayKey(today),
                    BoardPeriod.Week => CompetitionCalendar.WeekKey(today),
                    BoardPeriod.Month => CompetitionCalendar.MonthKey(today),
                    _ => BoardKeys.AllTimeKey,
                };
                final = query.Period != BoardPeriod.AllTime
                    && await competition.IsPeriodClosedAsync($"{query.Period.ToString().ToLowerInvariant()}:{gameKey}:{key}");
                break;
        }

        // Resolve the scope.
        string? country = null;
        string? scopeName = null;
        List<string>? members = null;
        switch (query.Scope)
        {
            case BoardScope.Country:
                country = query.Country?.Trim().ToUpperInvariant();
                if (string.IsNullOrEmpty(country))
                {
                    var profile = await profiles.GetByUserIdAsync(userId);
                    country = profile is null ? null : PlayerTimeZones.CountryFor(PlayerProfileRules.EffectiveTimeZone(profile, now));
                }
                if (string.IsNullOrEmpty(country) || country.Length != 2)
                    return AppResponse.RequestError("No country board for this player's time zone.");
                scopeName = CountryName(country);
                break;
            case BoardScope.Group:
                if (query.GroupId is not { } groupId || await groups.GetAsync(groupId) is not { } group)
                    return AppResponse.NotFound("Group not found.");
                if (!await groups.IsMemberAsync(groupId, userId))
                    return AppResponse.Forbidden("You are not in this group.");
                members = (await groups.GetMembersAsync(groupId)).Select(m => m.UserId.ToString()).ToList();
                scopeName = group.Name;
                break;
        }

        var board = query.Period switch
        {
            BoardPeriod.Round => BoardKeys.Run(challenge!.Id, country),
            BoardPeriod.Grand => BoardKeys.Grand(key, country),
            _ => BoardKeys.Game(gameKey!, query.Period, key, country),
        };

        IReadOnlyList<LeaderboardEntry> rows;
        LeaderboardEntry? mine;
        long total;
        if (members is not null)
        {
            var all = await boards.GetForMembersAsync(board, members);
            rows = all.Take(limit).ToList();
            mine = all.FirstOrDefault(e => e.MemberId == me);
            total = all.Count;
        }
        else
        {
            rows = await boards.GetTopAsync(board, 0, limit);
            mine = await boards.GetEntryAsync(board, me);
            total = await boards.CountAsync(board);
        }

        var ids = rows.Select(r => r.MemberId).Append(mine?.MemberId)
            .OfType<string>().Select(Guid.Parse).Distinct().ToList();
        var players = await competition.GetPlayersAsync(ids);

        // Run boards hold rank scores; show points (final, or what they would be if the run closed now).
        Dictionary<Guid, Attempt>? attempts = null;
        if (challenge is not null)
            attempts = (await competition.GetAttemptsForUsersAsync(challenge.Id, ids)).ToDictionary(a => a.UserId);

        BoardEntryDto ToDto(LeaderboardEntry e)
        {
            var id = Guid.Parse(e.MemberId);
            players.TryGetValue(id, out var player);
            Attempt? attempt = null;
            attempts?.TryGetValue(id, out attempt);
            var points = attempt is null
                ? e.Score
                : attempt.Points ?? ProvisionalPoints(challenge!.GameKey, e.Rank, total, attempt);
            return new BoardEntryDto
            {
                Rank = e.Rank,
                DisplayName = player.DisplayName ?? "Player",
                CountryCode = attempt?.CountryCode ?? player.CountryCode,
                Points = points,
                ElapsedMs = attempt?.ElapsedMs,
                IsMe = e.MemberId == me,
            };
        }

        var entries = rows.Select(ToDto).ToList();
        return AppResponse.Ok(new BoardResponse
        {
            Period = query.Period,
            Key = key,
            Scope = query.Scope,
            ScopeName = scopeName,
            GameKey = gameKey,
            Final = final,
            Total = total,
            Entries = entries,
            Me = mine is null || entries.Any(e => e.IsMe) ? null : ToDto(mine),
        });
    }
}
