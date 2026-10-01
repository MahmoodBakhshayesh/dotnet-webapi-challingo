using Challingo.Core.Domain.Enums;

namespace Challingo.Core.Domain.Entities;

/// <summary>A player's single try at a challenge. Times are server times only.</summary>
public class Attempt : BaseEntity
{
    public Guid ChallengeId { get; set; }
    public Challenge? Challenge { get; set; }
    public Guid UserId { get; set; }
    public AttemptStatus Status { get; set; }
    public DateTime StartedAtUtc { get; set; }
    public DateTime? SubmittedAtUtc { get; set; }
    public long? ElapsedMs { get; set; }

    /// <summary>Game-specific raw result (e.g. guesses, moves, word points) used for ranking.</summary>
    public string? ResultJson { get; set; }

    /// <summary>Final state + move log as sent by the app, kept for review and replay.</summary>
    public string? SubmissionJson { get; set; }

    /// <summary>Progress of an interactive game (guesses, revealed cells, found words). Never holds secrets.</summary>
    public string? StateJson { get; set; }

    /// <summary>Accepted moves so far; also the optimistic-concurrency token for <see cref="StateJson"/>.</summary>
    public int MoveCount { get; set; }

    /// <summary>Complete-but-wrong submissions in a race game (the attempt stays open after each).</summary>
    public int IncorrectSubmissions { get; set; }
}
