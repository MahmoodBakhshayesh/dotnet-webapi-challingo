using Challingo.Core.Domain.Entities;

namespace Challingo.Core.Domain.RepositoryInterfaces;

public interface IChallengeRepository
{
    /// <summary>Adds a puzzle and the challenge that offers it, in one save.</summary>
    Task AddAsync(Puzzle puzzle, Challenge challenge, CancellationToken ct = default);

    /// <summary>The challenge with its puzzle loaded.</summary>
    Task<Challenge?> GetChallengeAsync(Guid challengeId, CancellationToken ct = default);

    Task<Attempt?> GetAttemptAsync(Guid challengeId, Guid userId, CancellationToken ct = default);

    /// <summary>The attempt with its challenge and puzzle loaded.</summary>
    Task<Attempt?> GetAttemptWithPuzzleAsync(Guid attemptId, CancellationToken ct = default);

    /// <summary>Adds an attempt; false if this player already has one for the challenge (unique index).</summary>
    Task<bool> TryAddAttemptAsync(Attempt attempt, CancellationToken ct = default);

    /// <summary>
    /// Saves a finished attempt only if it is still in progress with <paramref name="expectedMoveCount"/> moves;
    /// false if another request changed it first.
    /// </summary>
    Task<bool> TryCompleteAttemptAsync(Attempt attempt, int expectedMoveCount, CancellationToken ct = default);

    /// <summary>Saves an interactive game's new state; false if another move landed first.</summary>
    Task<bool> TrySaveProgressAsync(Attempt attempt, int expectedMoveCount, CancellationToken ct = default);

    /// <summary>Counts a complete-but-wrong submission on an in-progress attempt.</summary>
    Task RecordIncorrectSubmissionAsync(Guid attemptId, CancellationToken ct = default);
}
