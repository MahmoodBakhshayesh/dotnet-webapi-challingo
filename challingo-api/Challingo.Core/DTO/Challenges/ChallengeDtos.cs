using Challingo.Core.Domain.Enums;
using Challingo.Core.DTO.Competition;
using Newtonsoft.Json.Linq;

namespace Challingo.Core.DTO.Challenges;

public sealed class ChallengeResponse
{
    public Guid ChallengeId { get; init; }
    public ChallengeKind Kind { get; init; }
    public required string GameKey { get; init; }
    public DateTime OpensAtUtc { get; init; }
    public DateTime ClosesAtUtc { get; init; }
}

public sealed class StartAttemptResponse
{
    public Guid AttemptId { get; init; }

    /// <summary>Send back with the submission; binds it to this attempt and player.</summary>
    public required string AttemptToken { get; init; }

    public required string GameKey { get; init; }

    /// <summary>The puzzle as the app may see it (never the solution).</summary>
    public required JToken Puzzle { get; init; }

    public DateTime StartedAtUtc { get; init; }
    public DateTime ClosesAtUtc { get; init; }

    /// <summary>For countdowns: the app computes its clock offset from this, never trusting device time.</summary>
    public DateTime ServerNowUtc { get; init; }

    /// <summary>True when an unfinished attempt was resumed; its clock kept running.</summary>
    public bool Resumed { get; init; }

    /// <summary>True when the game is played move by move through <c>/move</c>.</summary>
    public bool Interactive { get; init; }

    /// <summary>Progress so far for an interactive game (null when none yet).</summary>
    public JToken? State { get; init; }
}

public sealed class MoveAttemptRequest
{
    public string AttemptToken { get; set; } = "";

    /// <summary>Game-specific move (e.g. Code Breaker <c>{"guess":[0,3,3,5]}</c>).</summary>
    public JToken? Move { get; set; }
}

public sealed class MoveAttemptResponse
{
    public Guid AttemptId { get; init; }
    public AttemptStatus Status { get; init; }

    /// <summary>The server's answer to this move (feedback, revealed cells, word points…).</summary>
    public JToken? Response { get; init; }

    public int MoveCount { get; init; }

    /// <summary>Set once the move ended the attempt.</summary>
    public long? ElapsedMs { get; init; }

    /// <summary>Live rank once a move finished a shared challenge.</summary>
    public StandingDto? Standing { get; init; }
}

public sealed class SubmitAttemptRequest
{
    public string AttemptToken { get; set; } = "";

    /// <summary>Game-specific final state (e.g. Sudoku <c>{"cells":[…]}</c>).</summary>
    public JToken? Submission { get; set; }

    /// <summary>Optional move log with client timestamps, stored for review.</summary>
    public JToken? Moves { get; set; }
}

public sealed class SubmitAttemptResponse
{
    public Guid AttemptId { get; init; }
    public AttemptStatus Status { get; init; }
    public bool Solved { get; init; }

    /// <summary>Server finish minus server start.</summary>
    public long? ElapsedMs { get; init; }

    /// <summary>Why a submission was not accepted (e.g. "Some cells are wrong."); the attempt stays open.</summary>
    public string? Message { get; init; }

    /// <summary>The game's raw result (word points, guesses, moves…).</summary>
    public JToken? Result { get; init; }

    /// <summary>Live rank for a shared (daily, ranked, Grand) challenge.</summary>
    public StandingDto? Standing { get; init; }
}
