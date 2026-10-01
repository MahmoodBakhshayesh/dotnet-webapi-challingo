using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Newtonsoft.Json.Linq;
using Challingo.Core.Settings;
using Challingo.Infrastructure.Monetization;
using Xunit;

namespace Challingo.Tests;

public class AdMobSignatureTests
{
    private readonly ECDsa _key = ECDsa.Create(ECCurve.NamedCurves.nistP256);

    [Fact]
    public async Task Accepts_googles_signature_format_and_rejects_tampering()
    {
        var verifier = Verifier(("1234", _key));
        var query = Signed("ad_network=5450213213286189855&ad_unit=1234567890&reward_amount=1&reward_item=Reward&timestamp=150777823&transaction_id=12TUVWXYZ&user_id=0198f0aa-0000-7000-8000-000000000001", "1234", _key);

        Assert.True(await verifier.VerifyAsync(query));
        Assert.False(await verifier.VerifyAsync(query.Replace("user_id=0198", "user_id=0199")));
        Assert.False(await verifier.VerifyAsync(query.Replace("key_id=1234", "key_id=9999")));
        Assert.False(await verifier.VerifyAsync("ad_network=1&user_id=x"));
    }

    [Fact]
    public async Task Rejects_a_signature_from_another_key()
    {
        using var other = ECDsa.Create(ECCurve.NamedCurves.nistP256);
        var verifier = Verifier(("1234", _key));
        Assert.False(await verifier.VerifyAsync(Signed("transaction_id=1&user_id=u", "1234", other)));
    }

    /// <summary>AdMob signs the query up to "&amp;signature=" and appends signature (base64url DER) and key_id.</summary>
    private static string Signed(string content, string keyId, ECDsa key)
    {
        var signature = key.SignData(Encoding.UTF8.GetBytes(content), HashAlgorithmName.SHA256, DSASignatureFormat.Rfc3279DerSequence);
        var b64 = Convert.ToBase64String(signature).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        return $"{content}&signature={b64}&key_id={keyId}";
    }

    private static AdMobSignatureVerifier Verifier(params (string Id, ECDsa Key)[] keys)
    {
        var json = new JObject
        {
            ["keys"] = new JArray(keys.Select(k => new JObject
            {
                ["keyId"] = long.Parse(k.Id),
                ["base64"] = Convert.ToBase64String(k.Key.ExportSubjectPublicKeyInfo()),
            })),
        }.ToString();
        var http = new HttpClient(new StaticHandler(json));
        return new AdMobSignatureVerifier(http, new MemoryCache(new MemoryCacheOptions()),
            Options.Create(new MonetizationOptions { AdMob = new AdMobOptions { VerifierKeysUrl = "https://keys.test/keys.json" } }),
            NullLogger<AdMobSignatureVerifier>.Instance);
    }

    private sealed class StaticHandler(string body) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) =>
            Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK) { Content = new StringContent(body) });
    }
}

public class RevenueCatParseTests
{
    private static readonly DateTime Now = new(2026, 10, 5, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void Active_until_expiry_or_grace_period()
    {
        var active = RevenueCatClient.Parse(Subscriber("2026-11-05T12:00:00Z", null), "plus", Now)!;
        Assert.True(active.Active);
        Assert.Equal("APP_STORE", active.Store);
        Assert.Equal("challingo_plus_monthly", active.ProductId);

        Assert.False(RevenueCatClient.Parse(Subscriber("2026-10-01T00:00:00Z", null), "plus", Now)!.Active);
        // Billing issue: still active during the grace period.
        Assert.True(RevenueCatClient.Parse(Subscriber("2026-10-01T00:00:00Z", "2026-10-08T00:00:00Z"), "plus", Now)!.Active);
        // Lifetime: no expiry.
        Assert.True(RevenueCatClient.Parse(Subscriber(null, null), "plus", Now)!.Active);
        // No such entitlement.
        Assert.False(RevenueCatClient.Parse(Subscriber("2026-11-05T12:00:00Z", null), "gold", Now)!.Active);
    }

    private static JObject Subscriber(string? expires, string? grace) => JObject.Parse($$"""
        {
          "entitlements": { "plus": { "expires_date": {{Json(expires)}}, "grace_period_expires_date": {{Json(grace)}}, "product_identifier": "challingo_plus_monthly" } },
          "subscriptions": { "challingo_plus_monthly": { "store": "app_store" } }
        }
        """);

    private static string Json(string? s) => s is null ? "null" : $"\"{s}\"";
}
