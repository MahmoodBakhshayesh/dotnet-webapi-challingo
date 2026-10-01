using Microsoft.AspNetCore.Mvc;
using Challingo.Core.DTO.Challenges;

namespace Challingo.Core.ServiceInterfaces;

public interface IChallengeService
{
    /// <summary>Generates a fresh puzzle of <paramref name="gameKey"/> as an unranked practice challenge for this player.</summary>
    Task<ActionResult<ChallengeResponse>> CreatePracticeAsync(Guid userId, string gameKey);

    /// <summary>Starts (or resumes) the player's single attempt: records server start time, returns the puzzle + token.</summary>
    Task<ActionResult<StartAttemptResponse>> StartAsync(Guid userId, Guid challengeId);

    /// <summary>Sends one move of an interactive game; the server answers and keeps the progress.</summary>
    Task<ActionResult<MoveAttemptResponse>> MoveAsync(Guid userId, Guid attemptId, MoveAttemptRequest request);

    /// <summary>Verifies the submission on the server and records the result with server-measured time.</summary>
    Task<ActionResult<SubmitAttemptResponse>> SubmitAsync(Guid userId, Guid attemptId, SubmitAttemptRequest request);
}
