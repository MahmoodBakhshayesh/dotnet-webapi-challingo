using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Challingo.Api.Extensions;
using Challingo.Core.DTO.Competition;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Api.Controllers;

/// <summary>The daily lottery: today's draw, your pick, past results.</summary>
[Authorize]
public class LotteryController(ILotteryService lottery) : AppController
{
    [HttpGet("today")]
    public async Task<ActionResult<LotteryDto>> Today() =>
        User.GetUserId() is { } id ? await lottery.GetTodayResultAsync(id) : Unauthorized();

    /// <summary>Pick (or change) today's number until 14:00 UTC. An empty number picks at random.</summary>
    [HttpPost("pick")]
    public async Task<ActionResult<LotteryDto>> Pick(PickLotteryRequest request) =>
        User.GetUserId() is { } id ? await lottery.PickAsync(id, request) : Unauthorized();

    [HttpGet("history")]
    public async Task<ActionResult<List<LotteryDto>>> History() =>
        User.GetUserId() is { } id ? await lottery.GetHistoryAsync(id) : Unauthorized();
}
