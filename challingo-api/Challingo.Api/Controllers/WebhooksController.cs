using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Api.Controllers;

/// <summary>
/// Calls from AdMob and RevenueCat. No user token: AdMob callbacks are checked by signature,
/// RevenueCat calls by the shared Authorization header.
/// </summary>
[AllowAnonymous]
public class WebhooksController(IMonetizationService monetization) : AppController
{
    /// <summary>AdMob rewarded-ad server-side verification URL (set on the ad unit in AdMob).</summary>
    [HttpGet("admob/ssv")]
    public Task<IActionResult> AdMob(CancellationToken ct) =>
        monetization.HandleAdMobCallbackAsync(Request.QueryString.Value ?? "", ct);

    /// <summary>RevenueCat webhook URL (dashboard → Integrations → Webhooks).</summary>
    [HttpPost("revenuecat")]
    public async Task<IActionResult> RevenueCat(CancellationToken ct)
    {
        using var reader = new StreamReader(Request.Body);
        var body = await reader.ReadToEndAsync(ct);
        return await monetization.HandleRevenueCatWebhookAsync(Request.Headers.Authorization.ToString(), body, ct);
    }
}
