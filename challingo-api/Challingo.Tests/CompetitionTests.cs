using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Challingo.Core.Competition;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.Enums;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.Puzzles;
using Challingo.Core.Services;
using Challingo.Core.Settings;
using Xunit;

namespace Challingo.Tests;

public class CompetitionCalendarTests
{
    private static readonly TimeSpan HalfHour = TimeSpan.FromMinutes(30);

    [Fact]
    public void Runs_line_up_with_midnight_utc()
    {
        var t = new DateTime(2026, 10, 5, 13, 47, 10, DateTimeKind.Utc);
        Assert.Equal(new DateTime(2026, 10, 5, 13, 30, 0, DateTimeKind.Utc), CompetitionCalendar.RunStart(t, HalfHour));
        Assert.Equal(new DateTime(2026, 10, 5, 12, 0, 0, DateTimeKind.Utc), CompetitionCalendar.RunStart(t, TimeSpan.FromHours(2)));
        Assert.Equal(28, CompetitionCalendar.RunNumber(new DateTime(2026, 10, 5, 13, 30, 0, DateTimeKind.Utc), HalfHour));
        Assert.Equal(1, CompetitionCalendar.RunNumber(new DateTime(2026, 10, 5, 0, 0, 0, DateTimeKind.Utc), HalfHour));
        Assert.Equal("run:sudoku:2026-10-05T1200", CompetitionCalendar.RunSlot("sudoku", new DateTime(2026, 10, 5, 12, 0, 0, DateTimeKind.Utc)));
    }

    [Fact]
    public void Weeks_are_iso_weeks_and_months_are_utc()
    {
        Assert.Equal("2026-W41", CompetitionCalendar.WeekKey(new DateOnly(2026, 10, 5)));
        Assert.Equal("2026-W41", CompetitionCalendar.WeekKey(new DateOnly(2026, 10, 11)));
        Assert.Equal("2026-W42", CompetitionCalendar.WeekKey(new DateOnly(2026, 10, 12)));
        Assert.Equal("2026-W53", CompetitionCalendar.WeekKey(new DateOnly(2027, 1, 1)));
        Assert.Equal("2026-10", CompetitionCalendar.MonthKey(new DateOnly(2026, 10, 31)));
        Assert.Equal(new DateOnly(2026, 10, 11), CompetitionCalendar.WeekSunday(new DateOnly(2026, 10, 7)));
        Assert.True(CompetitionCalendar.IsGrandDay(new DateOnly(2026, 10, 11)));
    }

    [Fact]
    public void Timetable_defaults_overrides_and_switches()
    {
        var options = new CompetitionOptions();
        Assert.Equal(TimeSpan.FromMinutes(30), RunTimetable.For("path-link", options)!.Every);
        Assert.Equal(TimeSpan.FromHours(2), RunTimetable.For("sudoku", options)!.Every);

        options.Runs["sudoku"] = new GameRunOptions { EveryMinutes = 90 };
        options.Runs["kakuro"] = new GameRunOptions { EveryMinutes = 7 }; // does not divide a day: ignored
        options.Runs["nonogram"] = new GameRunOptions { Enabled = false };
        Assert.Equal(TimeSpan.FromMinutes(90), RunTimetable.For("sudoku", options)!.Every);
        Assert.Equal(TimeSpan.FromMinutes(30), RunTimetable.For("sudoku", options)!.Grace);
        Assert.Equal(TimeSpan.FromHours(2), RunTimetable.For("kakuro", options)!.Every);
        Assert.Null(RunTimetable.For("nonogram", options));
    }
}

public class LotteryRulesTests
{
    private static readonly DateOnly Day = new(2026, 10, 5);

    [Fact]
    public void Picks_close_at_14_and_a_digit_shows_every_hour()
    {
        Assert.Equal(new DateTime(2026, 10, 5, 14, 0, 0, DateTimeKind.Utc), LotteryRules.PicksCloseUtc(Day));
        Assert.Equal(new DateTime(2026, 10, 5, 15, 0, 0, DateTimeKind.Utc), LotteryRules.RevealAtUtc(Day, 1));
        Assert.Equal(new DateTime(2026, 10, 6, 0, 0, 0, DateTimeKind.Utc), LotteryRules.RevealAtUtc(Day, 10));
        Assert.Equal(0, LotteryRules.RevealedCount(Day, new DateTime(2026, 10, 5, 14, 59, 0, DateTimeKind.Utc)));
        Assert.Equal(1, LotteryRules.RevealedCount(Day, new DateTime(2026, 10, 5, 15, 0, 0, DateTimeKind.Utc)));
        Assert.Equal(9, LotteryRules.RevealedCount(Day, new DateTime(2026, 10, 5, 23, 59, 0, DateTimeKind.Utc)));
        Assert.Equal(10, LotteryRules.RevealedCount(Day, new DateTime(2026, 10, 6, 3, 0, 0, DateTimeKind.Utc)));
    }

    [Theory]
    [InlineData("1234567890", "1234567890", 10)]
    [InlineData("1299999999", "1234567890", 2)]
    [InlineData("0234567890", "1234567890", 0)]
    [InlineData("12", "1234567890", 2)]
    public void Match_counts_from_the_first_digit(string pick, string number, int expected) =>
        Assert.Equal(expected, LotteryRules.MatchLength(pick, number));

    [Fact]
    public void Numbers_and_commitments()
    {
        var n = LotteryRules.RandomNumber();
        Assert.True(LotteryRules.IsValidNumber(n));
        Assert.False(LotteryRules.IsValidNumber("12345"));
        Assert.False(LotteryRules.IsValidNumber("12345abcde"));
        Assert.Equal(64, LotteryRules.Commit("salt", n).Length);
        Assert.Equal(LotteryRules.Commit("salt", n), LotteryRules.Commit("salt", n));
        Assert.NotEqual(LotteryRules.Commit("salt", n), LotteryRules.Commit("other", n));
    }
}

public class RankScoreAndPointsTests
{
    [Fact]
    public void Solved_beats_failed_and_faster_beats_slower()
    {
        var fast = RankScore.Compute("sudoku", AttemptStatus.Solved, 60_000, null)!.Value;
        var slow = RankScore.Compute("sudoku", AttemptStatus.Solved, 90_000, null)!.Value;
        var failed = RankScore.Compute("mine-logic", AttemptStatus.Failed, 10_000, """{"revealed":30,"hitMine":true}""")!.Value;
        Assert.True(fast > slow);
        Assert.True(slow > failed);
        Assert.Null(RankScore.Compute("sudoku", AttemptStatus.Expired, null, null));
    }

    [Fact]
    public void Game_measure_ranks_before_time()
    {
        // Fewer guesses wins even when slower.
        var fewGuesses = RankScore.Compute("word-guess", AttemptStatus.Solved, 200_000, """{"guesses":3}""")!.Value;
        var manyGuesses = RankScore.Compute("word-guess", AttemptStatus.Solved, 20_000, """{"guesses":5}""")!.Value;
        Assert.True(fewGuesses > manyGuesses);

        var morePoints = RankScore.Compute("word-hunt", AttemptStatus.Solved, 150_000, """{"points":31}""")!.Value;
        var fewerPoints = RankScore.Compute("word-hunt", AttemptStatus.Solved, 150_000, """{"points":30}""")!.Value;
        Assert.True(morePoints > fewerPoints);

        var fewerMoves = RankScore.Compute("number-merge", AttemptStatus.Solved, 300_000, """{"moves":70}""")!.Value;
        var moreMoves = RankScore.Compute("number-merge", AttemptStatus.Solved, 100_000, """{"moves":71}""")!.Value;
        Assert.True(fewerMoves > moreMoves);
    }

    [Theory]
    [InlineData(1, 100, 1000)]
    [InlineData(100, 100, 0)]
    [InlineData(50, 99, 500)]
    [InlineData(1, 1, 1000)]
    public void Percentile_points(int rank, int n, int expected) =>
        Assert.Equal(expected, PointsCalculator.Percentile(rank, n));

    [Fact]
    public void Large_rounds_use_percentiles_and_ties_share_rank()
    {
        var attempts = Enumerable.Range(0, 60)
            .Select(i => Attempt(AttemptStatus.Solved, 60_000 + i * 1000))
            .Append(Attempt(AttemptStatus.Solved, 60_000)) // tie with the winner
            .Append(Attempt(AttemptStatus.Expired, null))
            .ToList();
        var points = PointsCalculator.Assign("sudoku", attempts, smallRoundThreshold: 50);

        var winners = points.Where(p => p.Rank == 1).ToList();
        Assert.Equal(2, winners.Count);
        Assert.All(winners, w => Assert.Equal(1000, w.Points));
        var expired = points.Single(p => p.RankScore is null);
        Assert.Equal(0, expired.Points);
        Assert.Equal(62, expired.Rank);
        // Points never go up as rank goes down.
        Assert.True(points.Zip(points.Skip(1)).All(p => p.First.Points >= p.Second.Points));
    }

    [Fact]
    public void Small_rounds_score_against_par_and_stay_in_rank_order()
    {
        var attempts = new List<ScoredAttempt>
        {
            Attempt(AttemptStatus.Solved, 120_000), // half of par
            Attempt(AttemptStatus.Solved, 480_000), // 2× par
            Attempt(AttemptStatus.Failed, 30_000),
        };
        var points = PointsCalculator.Assign("sudoku", attempts, smallRoundThreshold: 50);
        Assert.Equal([800, 500, 100], points.Select(p => p.Points));
        Assert.Equal([1, 2, 3], points.Select(p => p.Rank));
    }

    [Fact]
    public void Podium_shares_places_on_ties_and_skips_zero()
    {
        var podium = StarRewards.Podium([900.0, 1000, 900, 800, 0], s => s).ToList();
        Assert.Equal([(1000.0, 1), (900.0, 2), (900.0, 2)], podium);
        var stars = new StarAmounts();
        Assert.Equal(0, StarRewards.For(stars, BoardPeriod.Round, true, 1));
        Assert.Equal(20, StarRewards.For(stars, BoardPeriod.Day, true, 2));
        Assert.Equal(3, StarRewards.For(stars, BoardPeriod.Day, false, 3));
        Assert.Equal(20, StarRewards.For(stars, BoardPeriod.Week, false, 2));
        Assert.Equal(300, StarRewards.For(stars, BoardPeriod.Month, true, 1));
        Assert.Equal(300, StarRewards.For(stars, BoardPeriod.Grand, true, 1));
        Assert.Equal(0, StarRewards.For(stars, BoardPeriod.Week, true, 4));
        stars.DayGlobal = "50, 25";
        Assert.Equal(25, StarRewards.For(stars, BoardPeriod.Day, true, 2));
        Assert.Equal(0, StarRewards.For(stars, BoardPeriod.Day, true, 3));
    }

    [Theory]
    [InlineData("abcd2345", "ABCD2345")]
    [InlineData(" https://challingo.app/g/abcd2345 ", "ABCD2345")]
    public void Invite_codes_accept_links(string input, string expected) =>
        Assert.Equal(expected, GroupService.Normalize(input));

    private static ScoredAttempt Attempt(AttemptStatus status, long? ms) =>
        new(Guid.NewGuid(), Guid.NewGuid(), status, ms, null, RankScore.Compute("sudoku", status, ms, null), "DE");
}

public class CompetitionSchedulerTests
{
    private static readonly string[] Keys =
        ["sudoku", "kakuro", "nonogram", "path-link", "mine-logic", "code-breaker", "number-merge", "word-hunt", "word-guess", "mini-crossword"];

    [Fact]
    public async Task Schedules_every_game_on_its_timer_idempotently()
    {
        var repo = new FakeCompetitionRepository();
        var scheduler = Scheduler(repo, Keys, hoursAhead: 24);
        var monday = new DateTime(2026, 10, 5, 0, 0, 0, DateTimeKind.Utc);

        var created = await scheduler.EnsureScheduleAsync(monday);
        Assert.Equal(0, await scheduler.EnsureScheduleAsync(monday));

        var runs = repo.Challenges.Where(c => c.Kind == ChallengeKind.Ranked).ToList();
        // 24 h from 00:00: 4 games × 48 + 2 × 24 + 3 × 12 + 1 × 6.
        Assert.Equal(4 * 48 + 2 * 24 + 3 * 12 + 6, runs.Count);
        Assert.Equal(runs.Count + 6, created);

        var sudoku = runs.Where(c => c.GameKey == "sudoku").OrderBy(c => c.OpensAtUtc).ToList();
        Assert.Equal(12, sudoku.Count);
        Assert.Equal(new DateTime(2026, 10, 5, 2, 0, 0, DateTimeKind.Utc), sudoku[0].JoinClosesAtUtc);
        Assert.Equal(new DateTime(2026, 10, 5, 2, 30, 0, DateTimeKind.Utc), sudoku[0].ClosesAtUtc);
        Assert.Equal([1, 2, 3], sudoku.Take(3).Select(c => c.Sequence));
        Assert.All(sudoku, c => Assert.Equal(("2026-10-05", "2026-W41", "2026-10"), (c.PeriodKey, c.WeekKey, c.MonthKey)));

        var grand = repo.Challenges.Where(c => c.Kind == ChallengeKind.Grand).ToList();
        Assert.Equal(6, grand.Count);
        Assert.Equal(6, grand.Select(c => c.GameKey).Distinct().Count());
        Assert.All(grand, g => Assert.Equal(new DateTime(2026, 10, 11, 0, 0, 0, DateTimeKind.Utc), g.OpensAtUtc));
    }

    [Fact]
    public async Task Skips_games_without_content()
    {
        var repo = new FakeCompetitionRepository();
        var scheduler = Scheduler(repo, Keys, hoursAhead: 4, emptyContent: ["word-guess", "mini-crossword"]);
        await scheduler.EnsureScheduleAsync(new DateTime(2026, 10, 5, 0, 0, 0, DateTimeKind.Utc));
        Assert.DoesNotContain(repo.Challenges, c => c.GameKey is "word-guess" or "mini-crossword");
        Assert.Contains(repo.Challenges, c => c.GameKey == "sudoku");
    }

    private static CompetitionScheduler Scheduler(FakeCompetitionRepository repo, string[] keys, int hoursAhead, string[]? emptyContent = null) =>
        new(repo,
            new PuzzleGameRegistry(keys.Select(k => (IPuzzleGame)new StubGame(k, emptyContent?.Contains(k) == true))),
            Options.Create(new CompetitionOptions { ScheduleHoursAhead = hoursAhead, GrandDaysAhead = 6 }),
            NullLogger<CompetitionScheduler>.Instance);

    private sealed class StubGame(string key, bool noContent) : IPuzzleGame
    {
        public string Key => key;
        public int GeneratorVersion => 1;

        public ValueTask<GeneratedPuzzle> GenerateAsync(int seed, int difficulty, CancellationToken ct = default) =>
            noContent ? throw new PuzzleContentUnavailableException("none") : ValueTask.FromResult(new GeneratedPuzzle("{}", "{}"));

        public PuzzleVerdict Verify(PuzzleSubmission submission) => PuzzleVerdict.Solved();
    }
}

/// <summary>Only what the scheduler uses.</summary>
internal sealed class FakeCompetitionRepository : ICompetitionRepository
{
    public List<Challenge> Challenges { get; } = [];

    public Task<HashSet<string>> GetExistingSlotsAsync(IReadOnlyCollection<string> slotKeys, CancellationToken ct = default) =>
        Task.FromResult(Challenges.Select(c => c.SlotKey!).Where(slotKeys.Contains).ToHashSet());

    public Task<bool> TryAddScheduledAsync(Puzzle puzzle, Challenge challenge, CancellationToken ct = default)
    {
        if (Challenges.Any(c => c.SlotKey == challenge.SlotKey))
            return Task.FromResult(false);
        challenge.Puzzle = puzzle;
        Challenges.Add(challenge);
        return Task.FromResult(true);
    }

    public Task<List<Challenge>> GetGrandAsync(string weekKey, CancellationToken ct = default) =>
        Task.FromResult(Challenges.Where(c => c.Kind == ChallengeKind.Grand && c.WeekKey == weekKey).ToList());

    public Task<List<Challenge>> ListChallengesAsync(DateTime fromUtc, DateTime toUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<Challenge?> GetChallengeAsync(Guid challengeId, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<Dictionary<Guid, int>> CountAttemptsAsync(IReadOnlyCollection<Guid> challengeIds, CancellationToken ct = default) => throw new NotSupportedException();
    public Task ReplacePuzzleAsync(Guid challengeId, Puzzle puzzle, CancellationToken ct = default) => throw new NotSupportedException();
    public Task SetWindowAsync(Guid challengeId, DateTime opensAtUtc, DateTime joinClosesAtUtc, DateTime closesAtUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<int> CountRankedEntriesAsync(Guid userId, string dayKey, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<Dictionary<string, int>> CountRankedEntriesByGameAsync(Guid userId, string dayKey, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<Attempt>> GetUserAttemptsAsync(Guid userId, IReadOnlyCollection<Guid> challengeIds, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<Attempt>> GetAttemptsForUsersAsync(Guid challengeId, IReadOnlyCollection<Guid> userIds, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<Challenge>> ListAnnounceDueAsync(DateTime nowUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task MarkAnnouncedAsync(Guid challengeId, DateTime nowUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<Challenge>> ListFinalizeDueAsync(DateTime nowUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task ExpireOpenAttemptsAsync(Guid challengeId, DateTime nowUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<ScoredAttempt>> GetScoredAttemptsAsync(Guid challengeId, CancellationToken ct = default) => throw new NotSupportedException();
    public Task SaveFinalPointsAsync(IReadOnlyList<AttemptPoints> points, CancellationToken ct = default) => throw new NotSupportedException();
    public Task MarkFinalizedAsync(Guid challengeId, DateTime nowUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<string>> GetGamesWithRunsAsync(BoardPeriod period, string key, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<bool> HasUnfinalizedRunsAsync(string gameKey, BoardPeriod period, string key, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<bool> IsGrandFinalizedAsync(string weekKey, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<bool> IsPeriodClosedAsync(string key, CancellationToken ct = default) => throw new NotSupportedException();
    public Task MarkPeriodClosedAsync(string key, DateTime nowUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<PeriodResult>> GetGameResultsAsync(string gameKey, BoardPeriod period, string key, IReadOnlyCollection<Guid>? userIds = null, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<PeriodResult>> GetGrandResultsAsync(string weekKey, IReadOnlyCollection<Guid>? userIds = null, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<bool> TryAwardStarsAsync(Guid userId, int amount, string refKey, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<long> GetStarBalanceAsync(Guid userId, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<Dictionary<Guid, (string DisplayName, string? CountryCode)>> GetPlayersAsync(IReadOnlyCollection<Guid> userIds, CancellationToken ct = default) => throw new NotSupportedException();
}

public class CountryNameTests
{
    [Theory]
    [InlineData("DE", "Germany")]
    [InlineData("JP", "Japan")]
    [InlineData("ZZ", "ZZ")]
    public void Country_names_for_board_titles(string code, string expected) =>
        Assert.Equal(expected, CompetitionService.CountryName(code));
}
