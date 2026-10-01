using System.Security.Cryptography;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Challingo.Core.Competition;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.Enums;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.Puzzles;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services;

/// <summary>
/// Creates shared challenges ahead of time: every game's ranked runs on its own UTC timer
/// (<see cref="RunTimetable"/>), and each Sunday's Grand Challenge (different random games, open all day).
/// Every slot is unique, so runs are idempotent. A game without content (no approved words or crosswords)
/// is skipped until content arrives.
/// </summary>
public sealed class CompetitionScheduler(
    ICompetitionRepository competition,
    IPuzzleGameRegistry games,
    IOptions<CompetitionOptions> options,
    ILogger<CompetitionScheduler> logger) : ICompetitionScheduler
{
    private CompetitionOptions Options => options.Value;

    public async Task<int> EnsureScheduleAsync(DateTime nowUtc, CancellationToken ct = default)
    {
        var created = await EnsureRunsAsync(nowUtc, ct);
        created += await EnsureGrandAsync(nowUtc, ct);
        if (created > 0)
            logger.LogInformation("Scheduled {Count} challenges", created);
        return created;
    }

    private async Task<int> EnsureRunsAsync(DateTime nowUtc, CancellationToken ct)
    {
        var until = nowUtc.AddHours(Math.Max(1, Options.ScheduleHoursAhead));
        var planned = new List<(GameRun Run, DateTime Start)>();
        foreach (var key in games.Keys.Order())
        {
            if (RunTimetable.For(key, Options) is not { } run)
                continue;
            // From the run open now (it may have been missed) up to the horizon.
            for (var start = CompetitionCalendar.RunStart(nowUtc, run.Every); start < until; start += run.Every)
                planned.Add((run, start));
        }

        var existing = await competition.GetExistingSlotsAsync(planned.Select(p => CompetitionCalendar.RunSlot(p.Run.GameKey, p.Start)).ToList(), ct);
        var unavailable = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var created = 0;
        foreach (var (run, start) in planned)
        {
            var slot = CompetitionCalendar.RunSlot(run.GameKey, start);
            if (existing.Contains(slot) || unavailable.Contains(run.GameKey))
                continue;

            var puzzle = await TryGenerateAsync(run.GameKey, Options.RankedDifficulty, ct);
            if (puzzle is null)
            {
                unavailable.Add(run.GameKey);
                continue;
            }

            var date = CompetitionCalendar.UtcDate(start);
            var joinCloses = start + run.Every;
            if (await competition.TryAddScheduledAsync(puzzle, NewChallenge(ChallengeKind.Ranked, puzzle, slot, date,
                    CompetitionCalendar.RunNumber(start, run.Every), start, joinCloses, joinCloses + run.Grace), ct))
                created++;
        }
        return created;
    }

    private async Task<int> EnsureGrandAsync(DateTime nowUtc, CancellationToken ct)
    {
        var today = CompetitionCalendar.UtcDate(nowUtc);
        var created = 0;
        for (var sunday = CompetitionCalendar.WeekSunday(today); sunday <= today.AddDays(Options.GrandDaysAhead); sunday = sunday.AddDays(7))
        {
            var count = Math.Clamp(Options.GrandGames, 1, games.Keys.Count);
            var slots = Enumerable.Range(1, count).Select(s => CompetitionCalendar.GrandSlot(sunday, s)).ToList();
            var existing = await competition.GetExistingSlotsAsync(slots, ct);
            if (existing.Count == slots.Count)
                continue;

            var used = (await competition.GetGrandAsync(CompetitionCalendar.WeekKey(sunday), ct)).Select(c => c.GameKey).ToHashSet();
            var (opens, closes) = CompetitionCalendar.GrandWindow(sunday);
            var candidates = new Queue<string>(GameDraw.Distinct(games.Keys.Where(k => !used.Contains(k)).ToList(), games.Keys.Count, Random.Shared));
            for (var sequence = 1; sequence <= count; sequence++)
            {
                if (existing.Contains(CompetitionCalendar.GrandSlot(sunday, sequence)))
                    continue;
                // Next game that can be generated (content-based games may be out of content).
                Puzzle? puzzle = null;
                while (puzzle is null && candidates.TryDequeue(out var gameKey))
                    puzzle = await TryGenerateAsync(gameKey, Options.GrandDifficulty, ct);
                if (puzzle is null)
                    break;

                if (await competition.TryAddScheduledAsync(puzzle, NewChallenge(ChallengeKind.Grand, puzzle,
                        CompetitionCalendar.GrandSlot(sunday, sequence), sunday, sequence, opens, closes, closes), ct))
                    created++;
            }
        }
        return created;
    }

    private static Challenge NewChallenge(
        ChallengeKind kind, Puzzle puzzle, string slot, DateOnly date, int sequence, DateTime opens, DateTime joinCloses, DateTime closes) => new()
    {
        Id = Guid.CreateVersion7(),
        Kind = kind,
        PuzzleId = puzzle.Id,
        GameKey = puzzle.GameKey,
        OpensAtUtc = opens,
        JoinClosesAtUtc = joinCloses,
        ClosesAtUtc = closes,
        SlotKey = slot,
        PeriodKey = CompetitionCalendar.DayKey(date),
        WeekKey = CompetitionCalendar.WeekKey(date),
        MonthKey = CompetitionCalendar.MonthKey(date),
        Sequence = sequence,
    };

    internal async Task<Puzzle?> TryGenerateAsync(string gameKey, int difficulty, CancellationToken ct)
    {
        var game = games.Find(gameKey);
        if (game is null)
            return null;
        var seed = RandomNumberGenerator.GetInt32(int.MaxValue);
        try
        {
            var generated = await game.GenerateAsync(seed, difficulty, ct);
            return new Puzzle
            {
                Id = Guid.CreateVersion7(),
                GameKey = game.Key,
                Seed = seed,
                Difficulty = difficulty,
                GeneratorVersion = game.GeneratorVersion,
                PublicJson = generated.PublicJson,
                SecretJson = generated.SecretJson,
            };
        }
        catch (PuzzleContentUnavailableException ex)
        {
            logger.LogWarning("Skipping {Game}: {Reason}", gameKey, ex.Message);
            return null;
        }
    }
}
