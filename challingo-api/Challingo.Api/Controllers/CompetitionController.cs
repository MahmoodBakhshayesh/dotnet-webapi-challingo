using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Challingo.Api.Extensions;
using Challingo.Core.DTO.Competition;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Api.Controllers;

/// <summary>Today's rounds, daily puzzle and Grand Challenge; round, day, week, Grand and all-time boards.</summary>
[Authorize]
public class CompetitionController(ICompetitionService competition) : AppController
{
    [HttpGet("today")]
    public async Task<ActionResult<TodayResponse>> Today() =>
        User.GetUserId() is { } id ? await competition.GetTodayAsync(id) : Unauthorized();

    /// <summary>
    /// <c>?period=round&amp;key={challengeId}</c>, <c>?period=day&amp;key=2026-10-05</c>, <c>?period=week|grand&amp;key=2026-W41</c>,
    /// <c>?period=allTime</c>; <c>&amp;scope=global|country|group&amp;groupId=…</c>. An empty key means the current one.
    /// </summary>
    [HttpGet("boards")]
    public async Task<ActionResult<BoardResponse>> Board([FromQuery] BoardQuery query) =>
        User.GetUserId() is { } id ? await competition.GetBoardAsync(id, query) : Unauthorized();
}
