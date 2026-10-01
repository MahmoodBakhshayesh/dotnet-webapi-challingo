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
    [Fact]
    public void Rounds_are_fixed_four_hour_utc_windows()
    {
        var monday = new DateOnly(2026, 10, 5);
        Assert.Equal((new DateTime(2026, 10, 5, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 10, 5, 4, 0, 0, DateTimeKind.Utc)),
            CompetitionCalendar.RoundWindow(monday, 1));
        Assert.Equal((new DateTime(2026, 10, 5, 20, 0, 0, DateTimeKind.Utc), new DateTime(2026, 10, 6, 0, 0, 0, DateTimeKind.Utc)),
            CompetitionCalendar.RoundWindow(monday, 6));
        Assert.Equal(3, CompetitionCalendar.RoundAt(new DateTime(2026, 10, 5, 11, 59, 0, DateTimeKind.Utc)));
        Assert.Null(CompetitionCalendar.RoundAt(new DateTime(2026, 10, 11, 9, 0, 0, DateTimeKind.Utc)));
    }

    [Fact]
    public void Weeks_are_iso_weeks_starting_monday()
    {
        Assert.Equal("2026-W41", CompetitionCalendar.WeekKey(new DateOnly(2026, 10, 5)));
        Assert.Equal("2026-W41", CompetitionCalendar.WeekKey(new DateOnly(2026, 10, 11)));
        Assert.Equal("2026-W42", CompetitionCalendar.WeekKey(new DateOnly(2026, 10, 12)));
        Assert.Equal("2026-W53", CompetitionCalendar.WeekKey(new DateOnly(2027, 1, 1)));
        Assert.Equal(new DateOnly(2026, 10, 5), CompetitionCalendar.WeekStart(new DateOnly(2026, 10, 11)));
        Assert.True(CompetitionCalendar.IsGrandDay(new DateOnly(2026, 10, 11)));
    }

    [Fact]
    public void Daily_window_covers_every_time_zone()
    {
        var (opens, closes) = CompetitionCalendar.DailyWindow(new DateOnly(2026, 10, 5));
        Assert.Equal(new DateTime(2026, 10, 4, 10, 0, 0, DateTimeKind.Utc), opens);
        Assert.Equal(new DateTime(2026, 10, 6, 12, 0, 0, DateTimeKind.Utc), closes);
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
        Assert.Equal(10, StarRewards.For(BoardPeriod.Round, true, 1));
        Assert.Equal(1, StarRewards.For(BoardPeriod.Round, false, 3));
        Assert.Equal(20, StarRewards.For(BoardPeriod.Day, true, 2));
        Assert.Equal(30, StarRewards.For(BoardPeriod.Grand, true, 1));
        Assert.Equal(60, StarRewards.For(BoardPeriod.Week, false, 2));
        Assert.Equal(0, StarRewards.For(BoardPeriod.Week, true, 4));
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
    public async Task Schedules_dailies_rounds_and_grand_idempotently()
    {
        var repo = new FakeCompetitionRepository();
        var scheduler = Scheduler(repo, Keys);
        var monday = new DateTime(2026, 10, 5, 0, 30, 0, DateTimeKind.Utc);

        var created = await scheduler.EnsureScheduleAsync(monday);
        // Today + 8 days = Mon 5 … Tue 13: eight Mon–Sat days (daily + 6 rounds) and one Sunday (6 Grand games).
        Assert.Equal(8 * 7 + 6, created);
        Assert.Equal(0, await scheduler.EnsureScheduleAsync(monday));

        var week = repo.Challenges.Where(c => c.WeekKey == "2026-W41").ToList();
        var dailies = week.Where(c => c.Kind == ChallengeKind.Daily).OrderBy(c => c.LocalDate).Select(Game).ToList();
        Assert.Equal(6, dailies.Count);
        Assert.Equal(6, dailies.Distinct().Count());

        var grand = week.Where(c => c.Kind == ChallengeKind.Grand).OrderBy(c => c.Sequence).ToList();
        Assert.Equal(dailies, grand.Select(Game));
        Assert.All(grand, g => Assert.Equal(new DateTime(2026, 10, 11, 0, 0, 0, DateTimeKind.Utc), g.OpensAtUtc));

        var rounds = repo.Challenges.Where(c => c.Kind == ChallengeKind.Ranked).OrderBy(c => c.OpensAtUtc).ToList();
        Assert.DoesNotContain(rounds, c => CompetitionCalendar.IsGrandDay(CompetitionCalendar.UtcDate(c.OpensAtUtc)));
        Assert.All(rounds.Zip(rounds.Skip(1)), pair => Assert.NotEqual(Game(pair.First), Game(pair.Second)));
    }

    [Fact]
    public async Task Skips_games_without_content()
    {
        var repo = new FakeCompetitionRepository();
        var scheduler = Scheduler(repo, Keys, emptyContent: ["word-guess", "mini-crossword"]);
        await scheduler.EnsureScheduleAsync(new DateTime(2026, 10, 5, 0, 0, 0, DateTimeKind.Utc));
        Assert.DoesNotContain(repo.Challenges, c => Game(c) is "word-guess" or "mini-crossword");
        Assert.Equal(6, repo.Challenges.Count(c => c.Kind == ChallengeKind.Daily && c.WeekKey == "2026-W41"));
    }

    private string Game(Challenge c) => c.Puzzle!.GameKey;

    private static CompetitionScheduler Scheduler(FakeCompetitionRepository repo, string[] keys, string[]? emptyContent = null) =>
        new(repo,
            new PuzzleGameRegistry(keys.Select(k => (IPuzzleGame)new StubGame(k, emptyContent?.Contains(k) == true))),
            Options.Create(new CompetitionOptions { ScheduleDaysAhead = 8 }),
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

    public Task<string?> GetPreviousRankedGameAsync(DateTime beforeUtc, CancellationToken ct = default) =>
        Task.FromResult(Challenges.Where(c => c.Kind == ChallengeKind.Ranked && c.OpensAtUtc < beforeUtc)
            .OrderByDescending(c => c.OpensAtUtc).Select(c => c.Puzzle!.GameKey).FirstOrDefault());

    public Task<List<(DateOnly Date, string GameKey)>> GetFeaturedGamesAsync(string weekKey, CancellationToken ct = default) =>
        Task.FromResult(Challenges.Where(c => c.Kind == ChallengeKind.Daily && c.WeekKey == weekKey)
            .OrderBy(c => c.LocalDate).Select(c => (c.LocalDate!.Value, c.Puzzle!.GameKey)).ToList());

    public Task<bool> TryAddScheduledAsync(Puzzle puzzle, Challenge challenge, CancellationToken ct = default)
    {
        if (Challenges.Any(c => c.SlotKey == challenge.SlotKey))
            return Task.FromResult(false);
        challenge.Puzzle = puzzle;
        Challenges.Add(challenge);
        return Task.FromResult(true);
    }

    public Task<List<Challenge>> ListChallengesAsync(DateTime fromUtc, DateTime toUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<Challenge?> GetDailyAsync(DateOnly localDate, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<Challenge>> GetGrandAsync(string weekKey, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<Challenge?> GetChallengeAsync(Guid challengeId, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<Dictionary<Guid, int>> CountAttemptsAsync(IReadOnlyCollection<Guid> challengeIds, CancellationToken ct = default) => throw new NotSupportedException();
    public Task ReplacePuzzleAsync(Guid challengeId, Puzzle puzzle, CancellationToken ct = default) => throw new NotSupportedException();
    public Task SetWindowAsync(Guid challengeId, DateTime opensAtUtc, DateTime closesAtUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<int> CountRankedEntriesAsync(Guid userId, string dayKey, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<Attempt>> GetUserAttemptsAsync(Guid userId, IReadOnlyCollection<Guid> challengeIds, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<Attempt>> GetAttemptsForUsersAsync(Guid challengeId, IReadOnlyCollection<Guid> userIds, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<Challenge>> ListAnnounceDueAsync(DateTime nowUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task MarkAnnouncedAsync(Guid challengeId, DateTime nowUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<Challenge>> ListFinalizeDueAsync(DateTime nowUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task ExpireOpenAttemptsAsync(Guid challengeId, DateTime nowUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<ScoredAttempt>> GetScoredAttemptsAsync(Guid challengeId, CancellationToken ct = default) => throw new NotSupportedException();
    public Task SaveFinalPointsAsync(IReadOnlyList<AttemptPoints> points, CancellationToken ct = default) => throw new NotSupportedException();
    public Task MarkFinalizedAsync(Guid challengeId, DateTime nowUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<string>> GetClosableDaysAsync(CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<string>> GetClosableWeeksAsync(CancellationToken ct = default) => throw new NotSupportedException();
    public Task<bool> IsPeriodClosedAsync(string key, CancellationToken ct = default) => throw new NotSupportedException();
    public Task MarkPeriodClosedAsync(string key, DateTime nowUtc, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<PeriodResult>> GetDayResultsAsync(string dayKey, IReadOnlyCollection<Guid>? userIds = null, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<PeriodResult>> GetWeekResultsAsync(string weekKey, IReadOnlyCollection<Guid>? userIds = null, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<PeriodResult>> GetGrandResultsAsync(string weekKey, IReadOnlyCollection<Guid>? userIds = null, CancellationToken ct = default) => throw new NotSupportedException();
    public Task<List<PeriodResult>> GetAllTimeResultsAsync(IReadOnlyCollection<Guid> userIds, CancellationToken ct = default) => throw new NotSupportedException();
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
