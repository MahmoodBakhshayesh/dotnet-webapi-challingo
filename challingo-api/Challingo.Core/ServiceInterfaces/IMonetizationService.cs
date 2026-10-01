using Microsoft.AspNetCore.Mvc;
using Challingo.Core.DTO.Monetization;

namespace Challingo.Core.ServiceInterfaces;

public interface IMonetizationService
{
    Task<ActionResult<MonetizationStatusDto>> GetStatusAsync(Guid userId);

    /// <summary>Plus right now (unlimited ranked runs).</summary>
    Task<bool> IsPlusAsync(Guid userId, CancellationToken ct = default);

    /// <summary>Rewarded ads that count today (0–AdsPerDay).</summary>
    Task<int> AdsTodayAsync(Guid userId, CancellationToken ct = default);

    /// <summary>AdMob server-side verification callback. Always answers 200 to AdMob once the signature is valid.</summary>
    Task<IActionResult> HandleAdMobCallbackAsync(string rawQuery, CancellationToken ct = default);

    /// <summary>Development only: grants an ad reward without AdMob.</summary>
    Task<ActionResult<MonetizationStatusDto>> GrantDevAdAsync(Guid userId);

    /// <summary>RevenueCat webhook: checks the Authorization header, then re-reads the subscriber from RevenueCat.</summary>
    Task<IActionResult> HandleRevenueCatWebhookAsync(string? authorization, string body, CancellationToken ct = default);

    /// <summary>Re-reads the player's subscription from RevenueCat (called by the app right after a purchase or restore).</summary>
    Task<ActionResult<MonetizationStatusDto>> SyncPlusAsync(Guid userId);

    /// <summary>Development only: Plus for a number of days without a store.</summary>
    Task<ActionResult<MonetizationStatusDto>> GrantDevPlusAsync(Guid userId, int days);
}

/// <summary>Verifies AdMob server-side verification signatures with Google's published keys.</summary>
public interface IAdMobSignatureVerifier
{
    Task<bool> VerifyAsync(string rawQuery, CancellationToken ct = default);
}

/// <summary>Reads subscriber records from the RevenueCat REST API.</summary>
public interface IRevenueCatClient
{
    Task<RevenueCatEntitlement?> GetEntitlementAsync(string appUserId, CancellationToken ct = default);
}
