using Microsoft.EntityFrameworkCore;
using Npgsql;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.Enums;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Infrastructure.DbContexts;

namespace Challingo.Infrastructure.Repositories;

public sealed class ChallengeRepository(AppDbContext db) : IChallengeRepository
{
    public async Task AddAsync(Puzzle puzzle, Challenge challenge, CancellationToken ct = default)
    {
        db.Puzzles.Add(puzzle);
        db.Challenges.Add(challenge);
        await db.SaveChangesAsync(ct);
    }

    public Task<Challenge?> GetChallengeAsync(Guid challengeId, CancellationToken ct = default) =>
        db.Challenges.Include(x => x.Puzzle).FirstOrDefaultAsync(x => x.Id == challengeId, ct);

    public Task<Attempt?> GetAttemptAsync(Guid challengeId, Guid userId, CancellationToken ct = default) =>
        db.Attempts.FirstOrDefaultAsync(x => x.ChallengeId == challengeId && x.UserId == userId, ct);

    public Task<Attempt?> GetAttemptWithPuzzleAsync(Guid attemptId, CancellationToken ct = default) =>
        db.Attempts.Include(x => x.Challenge!).ThenInclude(c => c.Puzzle).FirstOrDefaultAsync(x => x.Id == attemptId, ct);

    public async Task<bool> TryAddAttemptAsync(Attempt attempt, CancellationToken ct = default)
    {
        db.Attempts.Add(attempt);
        try
        {
            await db.SaveChangesAsync(ct);
            return true;
        }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            db.Entry(attempt).State = EntityState.Detached;
            return false;
        }
    }

    public async Task<bool> TryCompleteAttemptAsync(Attempt attempt, int expectedMoveCount, CancellationToken ct = default)
    {
        // Conditional update: only the first finisher of an in-progress attempt wins.
        var now = DateTime.UtcNow;
        var updated = await db.Attempts
            .Where(x => x.Id == attempt.Id && x.Status == AttemptStatus.InProgress && x.MoveCount == expectedMoveCount)
            .ExecuteUpdateAsync(s => s
                .SetProperty(x => x.Status, attempt.Status)
                .SetProperty(x => x.SubmittedAtUtc, attempt.SubmittedAtUtc)
                .SetProperty(x => x.ElapsedMs, attempt.ElapsedMs)
                .SetProperty(x => x.ResultJson, attempt.ResultJson)
                .SetProperty(x => x.SubmissionJson, attempt.SubmissionJson)
                .SetProperty(x => x.StateJson, attempt.StateJson)
                .SetProperty(x => x.MoveCount, attempt.MoveCount)
                .SetProperty(x => x.RankScore, attempt.RankScore)
                .SetProperty(x => x.UpdatedAt, now), ct);
        return updated == 1;
    }

    public async Task<bool> TrySaveProgressAsync(Attempt attempt, int expectedMoveCount, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        var updated = await db.Attempts
            .Where(x => x.Id == attempt.Id && x.Status == AttemptStatus.InProgress && x.MoveCount == expectedMoveCount)
            .ExecuteUpdateAsync(s => s
                .SetProperty(x => x.StateJson, attempt.StateJson)
                .SetProperty(x => x.MoveCount, attempt.MoveCount)
                .SetProperty(x => x.UpdatedAt, now), ct);
        return updated == 1;
    }

    public Task RecordIncorrectSubmissionAsync(Guid attemptId, CancellationToken ct = default) =>
        db.Attempts
            .Where(x => x.Id == attemptId && x.Status == AttemptStatus.InProgress)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.IncorrectSubmissions, x => x.IncorrectSubmissions + 1), ct);
}
