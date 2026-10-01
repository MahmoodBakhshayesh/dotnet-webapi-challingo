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
/// Creates the shared challenges ahead of time: per Mon–Sat date a daily puzzle (that week's featured game,
/// six different ones) and six ranked rounds (random games, never the same twice in a row); per Sunday the
/// Grand Challenge (the week's featured games back to back). Every slot is unique, so runs are idempotent.
/// </summary>
public sealed class CompetitionScheduler(
    ICompetitionRepository competition,
    IPuzzleGameRegistry games,
    IOptions<CompetitionOptions> options,
    ILogger<CompetitionScheduler> logger) : ICompetitionScheduler
{
    public async Task<int> EnsureScheduleAsync(DateTime nowUtc, CancellationToken ct = default)
    {
        var today = CompetitionCalendar.UtcDate(nowUtc);
        var days = Enumerable.Range(0, Math.Max(1, options.Value.ScheduleDaysAhead) + 1).Select(today.AddDays).ToList();

        var slots = days.SelectMany(SlotsFor).ToList();
        var existing = await competition.GetExistingSlotsAsync(slots, ct);
        if (existing.Count == slots.Count)
            return 0;

        var unavailable = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var created = 0;
        foreach (var date in days)
        {
            if (CompetitionCalendar.IsGrandDay(date))
            {
                created += await EnsureGrandAsync(date, existing, unavailable, ct);
                continue;
            }

            var dailySlot = CompetitionCalendar.DailySlot(date);
            if (!existing.Contains(dailySlot))
            {
                var featured = (await competition.GetFeaturedGamesAsync(CompetitionCalendar.WeekKey(date), ct))
                    .Select(f => f.GameKey).ToList();
                var (opens, closes) = CompetitionCalendar.DailyWindow(date);
                if (await CreateAsync(dailySlot, ChallengeKind.Daily, 0, opens, closes, date, options.Value.DailyDifficulty,
                        available => GameDraw.Featured(available, featured, Random.Shared), unavailable, ct, localDate: date))
                    created++;
            }

            for (var sequence = 1; sequence <= CompetitionCalendar.RoundsPerDay; sequence++)
            {
                var slot = CompetitionCalendar.RankedSlot(date, sequence);
                if (existing.Contains(slot))
                    continue;
                var (opens, closes) = CompetitionCalendar.RoundWindow(date, sequence);
                var previous = await competition.GetPreviousRankedGameAsync(opens, ct);
                if (await CreateAsync(slot, ChallengeKind.Ranked, sequence, opens, closes, date, options.Value.RankedDifficulty,
                        available => GameDraw.Round(available, previous, Random.Shared), unavailable, ct))
                    created++;
            }
        }

        if (created > 0)
            logger.LogInformation("Scheduled {Count} challenges through {Last}", created, days[^1]);
        return created;
    }

    private static IEnumerable<string> SlotsFor(DateOnly date) =>
        CompetitionCalendar.IsGrandDay(date)
            ? Enumerable.Range(1, CompetitionCalendar.GrandGames).Select(s => CompetitionCalendar.GrandSlot(date, s))
            : Enumerable.Range(1, CompetitionCalendar.RoundsPerDay).Select(s => CompetitionCalendar.RankedSlot(date, s))
                .Prepend(CompetitionCalendar.DailySlot(date));

    private async Task<int> EnsureGrandAsync(DateOnly sunday, HashSet<string> existing, HashSet<string> unavailable, CancellationToken ct)
    {
        var weekKey = CompetitionCalendar.WeekKey(sunday);
        var featured = (await competition.GetFeaturedGamesAsync(weekKey, ct)).Select(f => f.GameKey).ToList();
        var used = new List<string>(featured);
        var (opens, closes) = CompetitionCalendar.GrandWindow(sunday);
        var created = 0;
        for (var sequence = 1; sequence <= CompetitionCalendar.GrandGames; sequence++)
        {
            var slot = CompetitionCalendar.GrandSlot(sunday, sequence);
            if (existing.Contains(slot))
                continue;

            // The week's featured game of that day; drawn when the week started without dailies.
            var planned = sequence <= featured.Count ? featured[sequence - 1] : null;
            if (await CreateAsync(slot, ChallengeKind.Grand, sequence, opens, closes, sunday, options.Value.GrandDifficulty,
                    available =>
                    {
                        var game = planned is not null && available.Contains(planned) ? planned : GameDraw.Featured(available, used, Random.Shared);
                        if (game is not null)
                            used.Add(game);
                        return game;
                    },
                    unavailable, ct))
            {
                created++;
            }
        }
        return created;
    }

    private async Task<bool> CreateAsync(
        string slot, ChallengeKind kind, int sequence, DateTime opens, DateTime closes, DateOnly date, int difficulty,
        Func<IReadOnlyList<string>, string?> draw, HashSet<string> unavailable, CancellationToken ct, DateOnly? localDate = null)
    {
        // Games whose content ran out (no approved words or crosswords) are skipped for this run.
        while (true)
        {
            var available = games.Keys.Where(k => !unavailable.Contains(k)).Order().ToList();
            var gameKey = draw(available);
            if (gameKey is null)
            {
                logger.LogError("No game can be generated for {Slot}", slot);
                return false;
            }

            var puzzle = await TryGenerateAsync(gameKey, difficulty, ct);
            if (puzzle is null)
            {
                unavailable.Add(gameKey);
                continue;
            }

            var challenge = new Challenge
            {
                Id = Guid.CreateVersion7(),
                Kind = kind,
                PuzzleId = puzzle.Id,
                OpensAtUtc = opens,
                ClosesAtUtc = closes,
                SlotKey = slot,
                PeriodKey = CompetitionCalendar.DayKey(date),
                WeekKey = CompetitionCalendar.WeekKey(date),
                Sequence = sequence,
                LocalDate = localDate,
            };
            return await competition.TryAddScheduledAsync(puzzle, challenge, ct);
        }
    }

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
