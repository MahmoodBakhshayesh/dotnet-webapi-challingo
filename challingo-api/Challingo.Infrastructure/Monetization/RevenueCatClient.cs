using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using Microsoft.Extensions.Options;
using Newtonsoft.Json.Linq;
using Challingo.Core.DTO.Monetization;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Infrastructure.Monetization;

/// <summary>GET /v1/subscribers/{app_user_id}: the source of truth for Plus (webhook bodies are only a trigger).</summary>
public sealed class RevenueCatClient(HttpClient http, IOptions<MonetizationOptions> options, TimeProvider clock) : IRevenueCatClient
{
    public async Task<RevenueCatEntitlement?> GetEntitlementAsync(string appUserId, CancellationToken ct = default)
    {
        var rc = options.Value.RevenueCat;
        if (!rc.Configured)
            return null;

        using var request = new HttpRequestMessage(HttpMethod.Get, new Uri(new Uri(rc.ApiBaseUrl), $"subscribers/{Uri.EscapeDataString(appUserId)}"));
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", rc.SecretApiKey);
        using var response = await http.SendAsync(request, ct);
        if (response.StatusCode == HttpStatusCode.NotFound)
            return null;
        response.EnsureSuccessStatusCode();

        var subscriber = JObject.Parse(await response.Content.ReadAsStringAsync(ct))["subscriber"] as JObject;
        return Parse(subscriber, rc.EntitlementId, clock.GetUtcNow().UtcDateTime);
    }

    /// <summary>Active when the entitlement exists and its expiry (or billing grace period) is in the future or absent.</summary>
    internal static RevenueCatEntitlement? Parse(JObject? subscriber, string entitlementId, DateTime nowUtc)
    {
        if (subscriber?["entitlements"]?[entitlementId] is not JObject entitlement)
            return new RevenueCatEntitlement(false, null, null, null);

        var expires = Date(entitlement["expires_date"]);
        var grace = Date(entitlement["grace_period_expires_date"]);
        var until = grace is { } g && (expires is null || g > expires) ? grace : expires;
        var product = entitlement.Value<string>("product_identifier");
        var store = product is null ? null : subscriber["subscriptions"]?[product]?.Value<string>("store")?.ToUpperInvariant();
        return new RevenueCatEntitlement(until is null || until > nowUtc, until, product, store);
    }

    private static DateTime? Date(JToken? token) =>
        token?.Type switch
        {
            JTokenType.Date => token.Value<DateTime>().ToUniversalTime(),
            JTokenType.String when DateTime.TryParse(token.Value<string>(), CultureInfo.InvariantCulture,
                DateTimeStyles.AdjustToUniversal | DateTimeStyles.AssumeUniversal, out var d) => d,
            _ => null,
        };
}
