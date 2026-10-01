using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Challingo.Core.Competition;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.Enums;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.Competition;
using Challingo.Core.DTO.Leaderboard;
using Challingo.Core.Players;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services;

/// <summary>Entry rules, live boards and the player's view of today's competition.</summary>
public sealed class CompetitionService(
    ICompetitionRepository competition,
    IPlayerProfileRepository profiles,
    IGroupRepository groups,
    ILeaderboardStore boards,
    IRealtimeNotifier realtime,
    IOptions<CompetitionOptions> options,
    TimeProvider clock) : ICompetitionService
{
    private CompetitionOptions Options => options.Value;

    public async Task<EntryDecision> CheckEntryAsync(Guid userId, Challenge challenge, DateTime nowUtc)
    {
        var profile = await profiles.GetByUserIdAsync(userId);
        if (profile is null)
            return EntryDecision.Deny("Player profile not found.", 404);

        var zone = PlayerProfileRules.EffectiveTimeZone(profile, nowUtc);
        var country = PlayerTimeZones.CountryFor(zone);

        switch (challenge.Kind)
        {
            case ChallengeKind.Daily:
                var localDate = PlayerTimeZones.LocalDate(zone, nowUtc);
                if (challenge.LocalDate != localDate)
                    return EntryDecision.Deny($"This daily puzzle is for {CompetitionCalendar.DayKey(challenge.LocalDate!.Value)}; it is {CompetitionCalendar.DayKey(localDate)} where you are.", 409);
                return new EntryDecision { CountryCode = country };

            case ChallengeKind.Ranked:
                var used = await competition.CountRankedEntriesAsync(userId, challenge.PeriodKey!);
                if (used >= AllowedRankedRounds(userId))
                    return EntryDecision.Deny("You have used today's ranked rounds. Watch an ad or go Plus to play more.", 402);
                return new EntryDecision { CountryCode = country, CountsForDay = used == 0 };

            default:
                return new EntryDecision { CountryCode = country };
        }
    }

    // Ads and Plus add rounds in Stage 3; until then everyone has the free allowance.
    private int AllowedRankedRounds(Guid userId) => Options.FreeRankedRoundsPerDay;

    public async Task<StandingDto?> OnAttemptCompletedAsync(Attempt attempt, Challenge challenge)
    {
        if (challenge.Kind == ChallengeKind.Practice || attempt.RankScore is not { } score)
            return null;

        var member = attempt.UserId.ToString();
        await boards.SetScoreAsync(BoardKeys.Round(challenge.Id), member, score);
        if (attempt.CountryCode is { } country)
            await boards.SetScoreAsync(BoardKeys.Round(challenge.Id, country), member, score);

        var gameKey = challenge.Puzzle?.GameKey ?? "";
        if (challenge.Kind == ChallengeKind.Grand && challenge.WeekKey is { } week)
        {
            // Live Grand board: par points until the day closes and percentiles are known.
            var par = PointsCalculator.ParPoints(gameKey, attempt.Status, attempt.ElapsedMs, attempt.ResultJson);
            await boards.IncrementAsync(BoardKeys.Grand(week), member, par);
            if (attempt.CountryCode is { } grandCountry)
                await boards.IncrementAsync(BoardKeys.Grand(week, grandCountry), member, par);
            await realtime.ToGroupAsync(BoardKeys.GrandTopic(week), "board.changed", new { period = BoardPeriod.Grand, key = week });
        }

        var entry = await boards.GetEntryAsync(BoardKeys.Round(challenge.Id), member);
        var players = await boards.CountAsync(BoardKeys.Round(challenge.Id));
        await realtime.ToGroupAsync(BoardKeys.Topic(challenge.Id), "board.changed", new { challengeId = challenge.Id, players });

        var rank = entry?.Rank ?? players;
        return new StandingDto
        {
            Rank = rank,
            Players = players,
            ProvisionalPoints = ProvisionalPoints(gameKey, rank, players, attempt),
        };
    }

    private int ProvisionalPoints(string gameKey, long rank, long players, Attempt attempt) =>
        players >= Options.SmallRoundThreshold
            ? PointsCalculator.Percentile(rank, players)
            : PointsCalculator.ParPoints(gameKey, attempt.Status, attempt.ElapsedMs, attempt.ResultJson);

    public async Task<ActionResult<TodayResponse>> GetTodayAsync(Guid userId)
    {
        var profile = await profiles.GetByUserIdAsync(userId);
        if (profile is null)
            return AppResponse.NotFound("Player profile not found.");

        var now = clock.GetUtcNow().UtcDateTime;
        var today = CompetitionCalendar.UtcDate(now);
        var zone = PlayerProfileRules.EffectiveTimeZone(profile, now);
        var localDate = PlayerTimeZones.LocalDate(zone, now);
        var weekKey = CompetitionCalendar.WeekKey(today);

        // Today's rounds plus enough ahead to find the next round across Sunday.
        var window = await competition.ListChallengesAsync(
            CompetitionCalendar.DayStartUtc(today), CompetitionCalendar.DayStartUtc(today).AddDays(2));
        var rounds = window
            .Where(c => c.Kind == ChallengeKind.Ranked && c.PeriodKey == CompetitionCalendar.DayKey(today))
            .OrderBy(c => c.Sequence).ToList();
        var nextRound = window
            .Where(c => c.Kind == ChallengeKind.Ranked && c.OpensAtUtc > now)
            .OrderBy(c => c.OpensAtUtc).FirstOrDefault();
        var daily = await competition.GetDailyAsync(localDate);
        var grand = await competition.GetGrandAsync(weekKey);

        var shown = rounds.Concat(grand).Append(daily).Append(nextRound).OfType<Challenge>().DistinctBy(c => c.Id).ToList();
        var mine = (await competition.GetUserAttemptsAsync(userId, shown.Select(c => c.Id).ToList()))
            .ToDictionary(a => a.ChallengeId);

        var used = await competition.CountRankedEntriesAsync(userId, CompetitionCalendar.DayKey(today));
        var featured = await competition.GetFeaturedGamesAsync(weekKey);

        return AppResponse.Ok(new TodayResponse
        {
            ServerNowUtc = now,
            UtcDate = today,
            LocalDate = localDate,
            WeekKey = weekKey,
            IsGrandDay = CompetitionCalendar.IsGrandDay(today),
            Rounds = rounds.Select(c => Card(c, now, mine)).ToList(),
            NextRound = nextRound is null ? null : Card(nextRound, now, mine),
            Daily = daily is null || CompetitionCalendar.IsGrandDay(localDate) ? null : Card(daily, now, mine),
            Grand = grand.Select(c => Card(c, now, mine)).ToList(),
            Featured = featured.Select(f => new FeaturedGameDto { Date = f.Date, GameKey = f.GameKey }).ToList(),
            RankedEntries = new EntryAllowanceDto
            {
                Used = used,
                Allowed = AllowedRankedRounds(userId),
                Free = Options.FreeRankedRoundsPerDay,
            },
            Stars = await competition.GetStarBalanceAsync(userId),
        });
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

    internal static ChallengeState StateAt(Challenge c, DateTime now) =>
        now < c.OpensAtUtc ? ChallengeState.Upcoming : now < c.ClosesAtUtc ? ChallengeState.Open : ChallengeState.Closed;

    private static ChallengeCardDto Card(Challenge c, DateTime now, IReadOnlyDictionary<Guid, Attempt> mine)
    {
        // Ranked games are announced one round ahead; the daily and Grand games are known all week.
        var announced = c.Kind != ChallengeKind.Ranked || c.OpensAtUtc <= now + CompetitionCalendar.RoundLength;
        mine.TryGetValue(c.Id, out var attempt);
        return new ChallengeCardDto
        {
            ChallengeId = c.Id,
            Kind = c.Kind,
            Sequence = c.Sequence,
            GameKey = announced ? c.Puzzle?.GameKey : null,
            OpensAtUtc = c.OpensAtUtc,
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
                CountsForDay = attempt.CountsForDay,
            },
        };
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
        bool final;
        switch (query.Period)
        {
            case BoardPeriod.Round:
                if (!Guid.TryParse(query.Key, out var challengeId)
                    || (challenge = await competition.GetChallengeAsync(challengeId)) is null
                    || challenge.Kind == ChallengeKind.Practice)
                    return AppResponse.NotFound("Round not found.");
                key = challenge.Id.ToString();
                final = challenge.FinalizedAtUtc is not null;
                break;
            case BoardPeriod.Day:
                key = string.IsNullOrWhiteSpace(query.Key) ? CompetitionCalendar.DayKey(today) : query.Key.Trim();
                final = await competition.IsPeriodClosedAsync($"day:{key}");
                break;
            case BoardPeriod.Week:
            case BoardPeriod.Grand:
                key = string.IsNullOrWhiteSpace(query.Key) ? CompetitionCalendar.WeekKey(today) : query.Key.Trim();
                final = await competition.IsPeriodClosedAsync($"week:{key}");
                break;
            default:
                key = "all";
                final = false;
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
            BoardPeriod.Round => BoardKeys.Round(challenge!.Id, country),
            BoardPeriod.Day => BoardKeys.Day(key, country),
            BoardPeriod.Week => BoardKeys.Week(key, country),
            BoardPeriod.Grand => BoardKeys.Grand(key, country),
            _ => BoardKeys.AllTime(country),
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

        // Round boards hold rank scores; show points (final, or what they would be if the round closed now).
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
                : attempt.Points ?? ProvisionalPoints(challenge!.Puzzle?.GameKey ?? "", e.Rank, total, attempt);
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
            GameKey = challenge?.Puzzle?.GameKey,
            Final = final,
            Total = total,
            Entries = entries,
            Me = mine is null || entries.Any(e => e.IsMe) ? null : ToDto(mine),
        });
    }
}
