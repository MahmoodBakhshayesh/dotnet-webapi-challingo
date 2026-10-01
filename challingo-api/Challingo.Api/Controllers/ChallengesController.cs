using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Challingo.Api.Extensions;
using Challingo.Core.DTO.Challenges;
using Challingo.Core.Puzzles;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Api.Controllers;

/// <summary>Puzzle engine: create practice challenges, start an attempt, submit it.</summary>
[Authorize]
public class ChallengesController(IChallengeService challenges, IPuzzleGameRegistry games) : AppController
{
    [HttpGet("games")]
    public ActionResult<IReadOnlyList<string>> Games() =>
        AppResponse.OkList(games.Keys.Order());

    [HttpPost("practice/{gameKey}")]
    public async Task<ActionResult<ChallengeResponse>> CreatePractice(string gameKey) =>
        User.GetUserId() is { } id ? await challenges.CreatePracticeAsync(id, gameKey) : Unauthorized();

    [HttpPost("{challengeId:guid}/start")]
    public async Task<ActionResult<StartAttemptResponse>> Start(Guid challengeId) =>
        User.GetUserId() is { } id ? await challenges.StartAsync(id, challengeId) : Unauthorized();

    [HttpPost("attempts/{attemptId:guid}/move")]
    public async Task<ActionResult<MoveAttemptResponse>> Move(Guid attemptId, MoveAttemptRequest request) =>
        User.GetUserId() is { } id ? await challenges.MoveAsync(id, attemptId, request) : Unauthorized();

    [HttpPost("attempts/{attemptId:guid}/submit")]
    public async Task<ActionResult<SubmitAttemptResponse>> Submit(Guid attemptId, SubmitAttemptRequest request) =>
        User.GetUserId() is { } id ? await challenges.SubmitAsync(id, attemptId, request) : Unauthorized();
}
