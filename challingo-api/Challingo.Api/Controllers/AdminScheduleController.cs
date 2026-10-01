using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Challingo.Core.DTO.Competition;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Api.Controllers;

/// <summary>Admin panel: the competition schedule.</summary>
[Authorize(Roles = Roles.Admin)]
[Route("api/admin/schedule")]
public class AdminScheduleController(IScheduleAdminService schedule) : AppController
{
    /// <summary>Scheduled challenges overlapping [from, to) (default: today and the next 7 days).</summary>
    [HttpGet]
    public Task<ActionResult<List<ScheduleEntryDto>>> List([FromQuery] DateTime? from, [FromQuery] DateTime? to)
    {
        var start = from?.ToUniversalTime() ?? DateTime.UtcNow.Date;
        return schedule.ListAsync(start, to?.ToUniversalTime() ?? start.AddDays(8));
    }

    /// <summary>Replaces the puzzle of a challenge that has not opened yet.</summary>
    [HttpPost("{challengeId:guid}/swap")]
    public Task<ActionResult<ScheduleEntryDto>> Swap(Guid challengeId, SwapPuzzleRequest request) =>
        schedule.SwapAsync(challengeId, request);

    /// <summary>Testing only (Competition__AllowAdminTimeTravel): move a challenge's window.</summary>
    [HttpPost("{challengeId:guid}/window")]
    public Task<ActionResult<ScheduleEntryDto>> SetWindow(Guid challengeId, SetWindowRequest request) =>
        schedule.SetWindowAsync(challengeId, request);

    /// <summary>Runs the Worker's scheduling and closing jobs now.</summary>
    [HttpPost("run")]
    public Task<ActionResult<CompetitionRunResponse>> Run() => schedule.RunNowAsync();
}
