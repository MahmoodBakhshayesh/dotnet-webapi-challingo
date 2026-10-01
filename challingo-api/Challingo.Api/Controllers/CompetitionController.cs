using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Challingo.Api.Extensions;
using Challingo.Core.DTO.Competition;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Api.Controllers;

/// <summary>The lobby (every game's runs, Grand Challenge, lottery) and all boards.</summary>
[Authorize]
public class CompetitionController(ICompetitionService competition) : AppController
{
    [HttpGet("lobby")]
    public async Task<ActionResult<LobbyResponse>> Lobby() =>
        User.GetUserId() is { } id ? await competition.GetLobbyAsync(id) : Unauthorized();

    /// <summary>
    /// <c>?period=round&amp;key={challengeId}</c>; <c>?period=day|week|month|allTime&amp;gameKey=sudoku[&amp;key=2026-10-05|2026-W41|2026-10]</c>;
    /// <c>?period=grand[&amp;key=2026-W41]</c>; plus <c>&amp;scope=global|country|group&amp;groupId=…</c>. An empty key means the current one.
    /// </summary>
    [HttpGet("boards")]
    public async Task<ActionResult<BoardResponse>> Board([FromQuery] BoardQuery query) =>
        User.GetUserId() is { } id ? await competition.GetBoardAsync(id, query) : Unauthorized();
}
