using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Newtonsoft.Json.Linq;
using Challingo.Core.Competition;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.Monetization;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services;

/// <summary>
/// Rewarded ads (+runs and +stars, a few a day) and Plus (unlimited ranked runs). Rewards are granted only from
/// AdMob's signed server callback; Plus only from RevenueCat's subscriber record. The app never grants either itself.
/// </summary>
public sealed class MonetizationService(
    IMonetizationRepository monetization,
    ICompetitionRepository competition,
    IPlayerProfileRepository profiles,
    IAdMobSignatureVerifier adMob,
    IRevenueCatClient revenueCat,
    IRealtimeNotifier realtime,
    IOptions<MonetizationOptions> options,
    TimeProvider clock,
    ILogger<MonetizationService> logger) : IMonetizationService
{
    private MonetizationOptions Options => options.Value;
    private DateTime Now => clock.GetUtcNow().UtcDateTime;
    private string Today => CompetitionCalendar.DayKey(CompetitionCalendar.UtcDate(Now));

    public async Task<ActionResult<MonetizationStatusDto>> GetStatusAsync(Guid userId) =>
        AppResponse.Ok(await StatusAsync(userId));

    private async Task<MonetizationStatusDto> StatusAsync(Guid userId, CancellationToken ct = default)
    {
        var entitlement = await monetization.GetEntitlementAsync(userId, ct);
        return new MonetizationStatusDto
        {
            Plus = new PlusStatusDto
            {
                Active = IsActive(entitlement),
                ExpiresAtUtc = entitlement?.ExpiresAtUtc,
                Store = entitlement?.Store,
            },
            AdsToday = await AdsTodayAsync(userId, ct),
            AdsPerDay = Options.AdsPerDay,
            RunsPerAd = Options.RunsPerAd,
            StarsPerAd = Options.StarsPerAd,
            RewardUserId = userId.ToString(),
            DevRewards = Options.AllowDevRewards,
        };
    }

    private bool IsActive(PlusEntitlement? e) => e is { Active: true } && (e.ExpiresAtUtc is null || e.ExpiresAtUtc > Now);

    public async Task<bool> IsPlusAsync(Guid userId, CancellationToken ct = default) =>
        IsActive(await monetization.GetEntitlementAsync(userId, ct));

    public async Task<int> AdsTodayAsync(Guid userId, CancellationToken ct = default) =>
        Math.Min(Options.AdsPerDay, await monetization.CountAdRewardsAsync(userId, Today, ct));

    // --- Rewarded ads -----------------------------------------------------------------------------

    public async Task<IActionResult> HandleAdMobCallbackAsync(string rawQuery, CancellationToken ct = default)
    {
        var query = rawQuery.TrimStart('?');
        if (!await adMob.VerifyAsync(query, ct))
        {
            logger.LogWarning("Rejected an AdMob callback with an invalid signature");
            return new UnauthorizedResult();
        }

        var values = System.Web.HttpUtility.ParseQueryString(query);
        var transactionId = values["transaction_id"];
        var adUnit = values["ad_unit"] ?? "";
        if (string.IsNullOrEmpty(transactionId) || !Guid.TryParse(values["user_id"], out var userId))
        {
            // Google's console "verify" ping has no user: accept so the URL can be saved.
            return new OkResult();
        }

        var allowed = Options.AdMob.AllowedAdUnits.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (allowed.Length > 0 && !allowed.Contains(adUnit))
        {
            logger.LogWarning("AdMob callback for unexpected ad unit {AdUnit}", adUnit);
            return new OkResult();
        }

        await GrantAdAsync(userId, $"admob:{transactionId}", adUnit, ct);
        return new OkResult();
    }

    public async Task<ActionResult<MonetizationStatusDto>> GrantDevAdAsync(Guid userId)
    {
        if (!Options.AllowDevRewards)
            return AppResponse.Forbidden("Test rewards are disabled (Monetization__AllowDevRewards).");
        if (!await GrantAdAsync(userId, $"dev:{Guid.CreateVersion7():N}", "dev"))
            return AppResponse.RequestError($"You have watched today's {Options.AdsPerDay} ads.", 409);
        return AppResponse.Ok(await StatusAsync(userId));
    }

    /// <summary>Records the ad (once per transaction, up to the daily limit) and pays its stars.</summary>
    private async Task<bool> GrantAdAsync(Guid userId, string transactionId, string adUnit, CancellationToken ct = default)
    {
        if (await profiles.GetByUserIdAsync(userId, ct) is null)
            return false;
        if (await monetization.CountAdRewardsAsync(userId, Today, ct) >= Options.AdsPerDay)
        {
            logger.LogInformation("Ad reward for {User} over the daily limit; not counted", userId);
            return false;
        }
        if (!await monetization.TryAddAdRewardAsync(new AdReward
            {
                Id = Guid.CreateVersion7(),
                UserId = userId,
                DayKey = Today,
                TransactionId = transactionId,
                AdUnit = adUnit,
                RewardedAtUtc = Now,
            }, ct))
            return false;

        if (Options.StarsPerAd > 0)
            await competition.TryAwardStarsAsync(userId, Options.StarsPerAd, $"ad:{transactionId}", ct);
        await realtime.ToUserAsync(userId.ToString(), "ad.rewarded", new { runs = Options.RunsPerAd, stars = Options.StarsPerAd }, ct);
        return true;
    }

    // --- Plus (RevenueCat) ------------------------------------------------------------------------

    public async Task<IActionResult> HandleRevenueCatWebhookAsync(string? authorization, string body, CancellationToken ct = default)
    {
        var expected = Options.RevenueCat.WebhookAuthorization;
        if (string.IsNullOrEmpty(expected) || !System.Security.Cryptography.CryptographicOperations.FixedTimeEquals(
                System.Text.Encoding.UTF8.GetBytes(authorization ?? ""), System.Text.Encoding.UTF8.GetBytes(expected)))
            return new UnauthorizedResult();

        JObject json;
        try
        {
            json = JObject.Parse(body);
        }
        catch (Newtonsoft.Json.JsonException)
        {
            return new BadRequestResult();
        }

        // Our app user ids are player ids; a purchase made before logIn may only list it among the aliases.
        var ev = json["event"] as JObject;
        var candidates = new[] { ev?.Value<string>("app_user_id"), ev?.Value<string>("original_app_user_id") }
            .Concat(ev?["aliases"]?.Values<string>() ?? [])
            .Concat(ev?["transferred_to"]?.Values<string>() ?? []);
        foreach (var candidate in candidates.Distinct())
        {
            if (Guid.TryParse(candidate, out var userId) && await profiles.GetByUserIdAsync(userId, ct) is not null)
                await RefreshPlusAsync(userId, ct);
        }
        // RevenueCat retries anything but 2xx; unknown users are not an error.
        return new OkResult();
    }

    public async Task<ActionResult<MonetizationStatusDto>> SyncPlusAsync(Guid userId)
    {
        if (!Options.RevenueCat.Configured)
            return AppResponse.Ok(await StatusAsync(userId));
        if (!await RefreshPlusAsync(userId))
            return AppResponse.RequestError("Could not reach the store. Try again in a moment.", 503);
        return AppResponse.Ok(await StatusAsync(userId));
    }

    /// <summary>Reads the subscriber from RevenueCat and stores the result.</summary>
    private async Task<bool> RefreshPlusAsync(Guid userId, CancellationToken ct = default)
    {
        RevenueCatEntitlement? entitlement;
        try
        {
            entitlement = await revenueCat.GetEntitlementAsync(userId.ToString(), ct);
        }
        catch (HttpRequestException ex)
        {
            logger.LogWarning(ex, "RevenueCat lookup failed for {User}", userId);
            return false;
        }

        var before = IsActive(await monetization.GetEntitlementAsync(userId, ct));
        await monetization.UpsertEntitlementAsync(new PlusEntitlement
        {
            UserId = userId,
            Active = entitlement?.Active ?? false,
            ExpiresAtUtc = entitlement?.ExpiresAtUtc,
            ProductId = entitlement?.ProductId,
            Store = entitlement?.Store,
            UpdatedAtUtc = Now,
        }, ct);

        var after = entitlement is { Active: true } && (entitlement.ExpiresAtUtc is null || entitlement.ExpiresAtUtc > Now);
        if (before != after)
            await realtime.ToUserAsync(userId.ToString(), "plus.changed", new { active = after }, ct);
        return true;
    }

    public async Task<ActionResult<MonetizationStatusDto>> GrantDevPlusAsync(Guid userId, int days)
    {
        if (!Options.AllowDevRewards)
            return AppResponse.Forbidden("Test Plus is disabled (Monetization__AllowDevRewards).");
        await monetization.UpsertEntitlementAsync(new PlusEntitlement
        {
            UserId = userId,
            Active = days > 0,
            ExpiresAtUtc = days > 0 ? Now.AddDays(days) : Now,
            ProductId = "dev",
            Store = "DEV",
            UpdatedAtUtc = Now,
        });
        await realtime.ToUserAsync(userId.ToString(), "plus.changed", new { active = days > 0 });
        return AppResponse.Ok(await StatusAsync(userId));
    }
}
