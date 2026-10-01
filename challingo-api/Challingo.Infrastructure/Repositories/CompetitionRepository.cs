using Microsoft.EntityFrameworkCore;
using Npgsql;
using Challingo.Core.Competition;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.Enums;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Infrastructure.DbContexts;

namespace Challingo.Infrastructure.Repositories;

public sealed class CompetitionRepository(AppDbContext db) : ICompetitionRepository
{
    private IQueryable<Challenge> Shared => db.Challenges.Where(c => c.SlotKey != null);

    // --- Schedule -----------------------------------------------------------------------------

    public async Task<HashSet<string>> GetExistingSlotsAsync(IReadOnlyCollection<string> slotKeys, CancellationToken ct = default) =>
        (await Shared.Where(c => slotKeys.Contains(c.SlotKey!)).Select(c => c.SlotKey!).ToListAsync(ct)).ToHashSet();

    public async Task<bool> TryAddScheduledAsync(Puzzle puzzle, Challenge challenge, CancellationToken ct = default)
    {
        db.Puzzles.Add(puzzle);
        db.Challenges.Add(challenge);
        try
        {
            await db.SaveChangesAsync(ct);
            return true;
        }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            // Another scheduler run created this slot first.
            db.Entry(challenge).State = EntityState.Detached;
            db.Entry(puzzle).State = EntityState.Detached;
            return false;
        }
    }

    public Task<List<Challenge>> ListChallengesAsync(DateTime fromUtc, DateTime toUtc, CancellationToken ct = default) =>
        Shared.AsNoTracking().Include(c => c.Puzzle)
            .Where(c => c.OpensAtUtc < toUtc && c.ClosesAtUtc > fromUtc)
            .OrderBy(c => c.OpensAtUtc).ThenBy(c => c.Kind).ThenBy(c => c.Sequence)
            .ToListAsync(ct);

    public Task<List<Challenge>> GetGrandAsync(string weekKey, CancellationToken ct = default) =>
        Shared.AsNoTracking().Include(c => c.Puzzle)
            .Where(c => c.Kind == ChallengeKind.Grand && c.WeekKey == weekKey)
            .OrderBy(c => c.Sequence)
            .ToListAsync(ct);

    public Task<Challenge?> GetChallengeAsync(Guid challengeId, CancellationToken ct = default) =>
        db.Challenges.AsNoTracking().Include(c => c.Puzzle).FirstOrDefaultAsync(c => c.Id == challengeId, ct);

    public async Task<Dictionary<Guid, int>> CountAttemptsAsync(IReadOnlyCollection<Guid> challengeIds, CancellationToken ct = default) =>
        await db.Attempts.Where(a => challengeIds.Contains(a.ChallengeId))
            .GroupBy(a => a.ChallengeId)
            .Select(g => new { g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.Key, x => x.Count, ct);

    public async Task ReplacePuzzleAsync(Guid challengeId, Puzzle puzzle, CancellationToken ct = default)
    {
        db.Puzzles.Add(puzzle);
        await db.SaveChangesAsync(ct);
        await db.Challenges.Where(c => c.Id == challengeId)
            .ExecuteUpdateAsync(s => s
                .SetProperty(c => c.PuzzleId, puzzle.Id)
                .SetProperty(c => c.GameKey, puzzle.GameKey)
                .SetProperty(c => c.UpdatedAt, DateTime.UtcNow), ct);
    }

    public Task SetWindowAsync(Guid challengeId, DateTime opensAtUtc, DateTime joinClosesAtUtc, DateTime closesAtUtc, CancellationToken ct = default) =>
        db.Challenges.Where(c => c.Id == challengeId)
            .ExecuteUpdateAsync(s => s
                .SetProperty(c => c.OpensAtUtc, opensAtUtc)
                .SetProperty(c => c.JoinClosesAtUtc, joinClosesAtUtc)
                .SetProperty(c => c.ClosesAtUtc, closesAtUtc)
                .SetProperty(c => c.AnnouncedAtUtc, (DateTime?)null)
                .SetProperty(c => c.UpdatedAt, DateTime.UtcNow), ct);

    // --- Entry --------------------------------------------------------------------------------

    public Task<int> CountRankedEntriesAsync(Guid userId, string dayKey, CancellationToken ct = default) =>
        db.Attempts.CountAsync(a => a.UserId == userId
            && a.Challenge!.Kind == ChallengeKind.Ranked && a.Challenge.PeriodKey == dayKey, ct);

    public async Task<Dictionary<string, int>> CountRankedEntriesByGameAsync(Guid userId, string dayKey, CancellationToken ct = default) =>
        await db.Attempts
            .Where(a => a.UserId == userId && a.Challenge!.Kind == ChallengeKind.Ranked && a.Challenge.PeriodKey == dayKey)
            .GroupBy(a => a.Challenge!.GameKey)
            .Select(g => new { g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.Key, x => x.Count, ct);

    public Task<List<Attempt>> GetUserAttemptsAsync(Guid userId, IReadOnlyCollection<Guid> challengeIds, CancellationToken ct = default) =>
        db.Attempts.AsNoTracking().Where(a => a.UserId == userId && challengeIds.Contains(a.ChallengeId)).ToListAsync(ct);

    public Task<List<Attempt>> GetAttemptsForUsersAsync(Guid challengeId, IReadOnlyCollection<Guid> userIds, CancellationToken ct = default) =>
        db.Attempts.AsNoTracking().Where(a => a.ChallengeId == challengeId && userIds.Contains(a.UserId)).ToListAsync(ct);

    // --- Closing ------------------------------------------------------------------------------

    public Task<List<Challenge>> ListAnnounceDueAsync(DateTime nowUtc, CancellationToken ct = default) =>
        Shared.AsNoTracking().Include(c => c.Puzzle)
            .Where(c => c.Kind == ChallengeKind.Ranked && c.AnnouncedAtUtc == null && c.OpensAtUtc <= nowUtc && c.JoinClosesAtUtc > nowUtc)
            .ToListAsync(ct);

    public Task MarkAnnouncedAsync(Guid challengeId, DateTime nowUtc, CancellationToken ct = default) =>
        db.Challenges.Where(c => c.Id == challengeId).ExecuteUpdateAsync(s => s.SetProperty(c => c.AnnouncedAtUtc, nowUtc), ct);

    public Task<List<Challenge>> ListFinalizeDueAsync(DateTime nowUtc, CancellationToken ct = default) =>
        Shared.AsNoTracking().Include(c => c.Puzzle)
            .Where(c => c.FinalizedAtUtc == null && c.ClosesAtUtc <= nowUtc)
            .OrderBy(c => c.ClosesAtUtc)
            .ToListAsync(ct);

    public Task ExpireOpenAttemptsAsync(Guid challengeId, DateTime nowUtc, CancellationToken ct = default) =>
        db.Attempts.Where(a => a.ChallengeId == challengeId && a.Status == AttemptStatus.InProgress)
            .ExecuteUpdateAsync(s => s
                .SetProperty(a => a.Status, AttemptStatus.Expired)
                .SetProperty(a => a.SubmittedAtUtc, nowUtc)
                .SetProperty(a => a.UpdatedAt, nowUtc), ct);

    public Task<List<ScoredAttempt>> GetScoredAttemptsAsync(Guid challengeId, CancellationToken ct = default) =>
        db.Attempts.AsNoTracking().Where(a => a.ChallengeId == challengeId)
            .Select(a => new ScoredAttempt(a.Id, a.UserId, a.Status, a.ElapsedMs, a.ResultJson, a.RankScore, a.CountryCode))
            .ToListAsync(ct);

    public async Task SaveFinalPointsAsync(IReadOnlyList<AttemptPoints> points, CancellationToken ct = default)
    {
        // One statement per 5,000 rows: UPDATE … FROM unnest(ids, points, ranks).
        foreach (var chunk in points.Chunk(5000))
        {
            var ids = chunk.Select(p => p.AttemptId).ToArray();
            var values = chunk.Select(p => p.Points).ToArray();
            var ranks = chunk.Select(p => p.Rank).ToArray();
            await db.Database.ExecuteSqlInterpolatedAsync($"""
                UPDATE "Attempts" AS a SET "Points" = v.points, "Rank" = v.rank
                FROM unnest({ids}::uuid[], {values}::int[], {ranks}::int[]) AS v(id, points, rank)
                WHERE a."Id" = v.id
                """, ct);
        }
    }

    public Task MarkFinalizedAsync(Guid challengeId, DateTime nowUtc, CancellationToken ct = default) =>
        db.Challenges.Where(c => c.Id == challengeId).ExecuteUpdateAsync(s => s.SetProperty(c => c.FinalizedAtUtc, nowUtc), ct);

    public async Task<List<string>> GetGamesWithRunsAsync(BoardPeriod period, string key, CancellationToken ct = default) =>
        await InPeriod(Shared.Where(c => c.Kind == ChallengeKind.Ranked), period, key)
            .Select(c => c.GameKey).Distinct().ToListAsync(ct);

    public Task<bool> HasUnfinalizedRunsAsync(string gameKey, BoardPeriod period, string key, CancellationToken ct = default) =>
        InPeriod(Shared.Where(c => c.Kind == ChallengeKind.Ranked && c.GameKey == gameKey), period, key)
            .AnyAsync(c => c.FinalizedAtUtc == null, ct);

    public async Task<bool> IsGrandFinalizedAsync(string weekKey, CancellationToken ct = default)
    {
        var grand = Shared.Where(c => c.Kind == ChallengeKind.Grand && c.WeekKey == weekKey);
        return await grand.AnyAsync(ct) && !await grand.AnyAsync(c => c.FinalizedAtUtc == null, ct);
    }

    private static IQueryable<Challenge> InPeriod(IQueryable<Challenge> query, BoardPeriod period, string key) => period switch
    {
        BoardPeriod.Day => query.Where(c => c.PeriodKey == key),
        BoardPeriod.Week => query.Where(c => c.WeekKey == key),
        BoardPeriod.Month => query.Where(c => c.MonthKey == key),
        _ => query,
    };

    public Task<bool> IsPeriodClosedAsync(string key, CancellationToken ct = default) =>
        db.PeriodCloses.AnyAsync(p => p.Key == key, ct);

    public Task MarkPeriodClosedAsync(string key, DateTime nowUtc, CancellationToken ct = default) =>
        db.Database.ExecuteSqlInterpolatedAsync(
            $"""INSERT INTO "PeriodCloses" ("Key", "ClosedAtUtc") VALUES ({key}, {nowUtc}) ON CONFLICT ("Key") DO NOTHING""", ct);

    public Task<List<PeriodResult>> GetGameResultsAsync(string gameKey, BoardPeriod period, string key, IReadOnlyCollection<Guid>? userIds = null, CancellationToken ct = default)
    {
        var query = db.Attempts.Where(a => a.Points != null && a.Challenge!.Kind == ChallengeKind.Ranked && a.Challenge.GameKey == gameKey);
        query = period switch
        {
            BoardPeriod.Day => query.Where(a => a.Challenge!.PeriodKey == key),
            BoardPeriod.Week => query.Where(a => a.Challenge!.WeekKey == key),
            BoardPeriod.Month => query.Where(a => a.Challenge!.MonthKey == key),
            _ => query,
        };
        return TotalsAsync(query, userIds, ct);
    }

    public Task<List<PeriodResult>> GetGrandResultsAsync(string weekKey, IReadOnlyCollection<Guid>? userIds = null, CancellationToken ct = default) =>
        TotalsAsync(db.Attempts.Where(a => a.Points != null && a.Challenge!.Kind == ChallengeKind.Grand && a.Challenge.WeekKey == weekKey), userIds, ct);

    private static async Task<List<PeriodResult>> TotalsAsync(IQueryable<Attempt> query, IReadOnlyCollection<Guid>? userIds, CancellationToken ct)
    {
        if (userIds is not null)
            query = query.Where(a => userIds.Contains(a.UserId));
        var rows = await query.Select(a => new { a.UserId, a.Points, a.CountryCode, a.StartedAtUtc }).ToListAsync(ct);
        return rows.GroupBy(r => r.UserId)
            .Select(g => new PeriodResult(
                g.Key,
                g.Sum(r => r.Points!.Value),
                g.OrderByDescending(r => r.StartedAtUtc).Select(r => r.CountryCode).FirstOrDefault()))
            .ToList();
    }

    // --- Stars --------------------------------------------------------------------------------

    public async Task<bool> TryAwardStarsAsync(Guid userId, int amount, string refKey, CancellationToken ct = default)
    {
        var inserted = await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO "StarTransactions" ("Id", "UserId", "Amount", "RefKey", "CreatedAt", "IsDeleted")
            VALUES ({Guid.CreateVersion7()}, {userId}, {amount}, {refKey}, {DateTime.UtcNow}, FALSE)
            ON CONFLICT ("UserId", "RefKey") DO NOTHING
            """, ct);
        return inserted == 1;
    }

    public async Task<long> GetStarBalanceAsync(Guid userId, CancellationToken ct = default) =>
        await db.StarTransactions.Where(s => s.UserId == userId).SumAsync(s => (long)s.Amount, ct);

    // --- Players ------------------------------------------------------------------------------

    public async Task<Dictionary<Guid, (string DisplayName, string? CountryCode)>> GetPlayersAsync(IReadOnlyCollection<Guid> userIds, CancellationToken ct = default) =>
        (await db.PlayerProfiles.AsNoTracking().Where(p => userIds.Contains(p.UserId))
            .Select(p => new { p.UserId, p.DisplayName, p.CountryCode })
            .ToListAsync(ct))
        .ToDictionary(p => p.UserId, p => (p.DisplayName, p.CountryCode));
}
