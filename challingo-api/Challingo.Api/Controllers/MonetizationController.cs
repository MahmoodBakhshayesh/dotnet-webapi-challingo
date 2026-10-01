using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Challingo.Api.Extensions;
using Challingo.Core.DTO.Monetization;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Api.Controllers;

/// <summary>Rewarded ads and Plus for the signed-in player.</summary>
[Authorize]
public class MonetizationController(IMonetizationService monetization) : AppController
{
    [HttpGet("status")]
    public async Task<ActionResult<MonetizationStatusDto>> Status() =>
        User.GetUserId() is { } id ? await monetization.GetStatusAsync(id) : Unauthorized();

    /// <summary>Re-reads Plus from RevenueCat right after a purchase or restore.</summary>
    [HttpPost("plus/sync")]
    public async Task<ActionResult<MonetizationStatusDto>> SyncPlus() =>
        User.GetUserId() is { } id ? await monetization.SyncPlusAsync(id) : Unauthorized();

    /// <summary>Development only (Monetization__AllowDevRewards): a rewarded ad without AdMob.</summary>
    [HttpPost("ads/dev-reward")]
    public async Task<ActionResult<MonetizationStatusDto>> DevReward() =>
        User.GetUserId() is { } id ? await monetization.GrantDevAdAsync(id) : Unauthorized();

    /// <summary>Development only: Plus for <paramref name="days"/> days (0 ends it).</summary>
    [HttpPost("plus/dev")]
    public async Task<ActionResult<MonetizationStatusDto>> DevPlus([FromQuery] int days = 30) =>
        User.GetUserId() is { } id ? await monetization.GrantDevPlusAsync(id, days) : Unauthorized();
}
