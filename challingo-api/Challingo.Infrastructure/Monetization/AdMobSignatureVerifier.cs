using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Newtonsoft.Json.Linq;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Infrastructure.Monetization;

/// <summary>
/// AdMob server-side verification: the callback query is signed with ECDSA P-256 / SHA-256. The signed content is
/// the query up to <c>&amp;signature=</c>; <c>key_id</c> names one of Google's published keys (cached for a day,
/// refreshed once when an unknown key id shows up).
/// </summary>
public sealed class AdMobSignatureVerifier(HttpClient http, IMemoryCache cache, IOptions<MonetizationOptions> options, ILogger<AdMobSignatureVerifier> logger)
    : IAdMobSignatureVerifier
{
    private const string CacheKey = "admob-verifier-keys";

    public async Task<bool> VerifyAsync(string rawQuery, CancellationToken ct = default)
    {
        var at = rawQuery.IndexOf("&signature=", StringComparison.Ordinal);
        if (at <= 0)
            return false;
        var message = Encoding.UTF8.GetBytes(rawQuery[..at]);
        var values = System.Web.HttpUtility.ParseQueryString(rawQuery);
        var keyId = values["key_id"];
        var signature = DecodeBase64Url(values["signature"]);
        if (string.IsNullOrEmpty(keyId) || signature is null)
            return false;

        var keys = await GetKeysAsync(refresh: false, ct);
        if (!keys.ContainsKey(keyId))
            keys = await GetKeysAsync(refresh: true, ct);
        if (!keys.TryGetValue(keyId, out var spki))
            return false;

        using var ecdsa = ECDsa.Create();
        ecdsa.ImportSubjectPublicKeyInfo(spki, out _);
        return ecdsa.VerifyData(message, signature, HashAlgorithmName.SHA256, DSASignatureFormat.Rfc3279DerSequence);
    }

    private async Task<Dictionary<string, byte[]>> GetKeysAsync(bool refresh, CancellationToken ct)
    {
        if (!refresh && cache.TryGetValue(CacheKey, out Dictionary<string, byte[]>? cached) && cached is not null)
            return cached;
        try
        {
            var json = JObject.Parse(await http.GetStringAsync(options.Value.AdMob.VerifierKeysUrl, ct));
            var keys = (json["keys"] as JArray ?? [])
                .Select(k => (Id: k.Value<string>("keyId"), Base64: k.Value<string>("base64")))
                .Where(k => k.Id is not null && k.Base64 is not null)
                .ToDictionary(k => k.Id!, k => Convert.FromBase64String(k.Base64!));
            cache.Set(CacheKey, keys, TimeSpan.FromHours(24));
            return keys;
        }
        catch (Exception ex) when (ex is HttpRequestException or Newtonsoft.Json.JsonException or FormatException)
        {
            logger.LogWarning(ex, "Could not load AdMob verifier keys");
            return cache.TryGetValue(CacheKey, out Dictionary<string, byte[]>? stale) && stale is not null ? stale : [];
        }
    }

    internal static byte[]? DecodeBase64Url(string? value)
    {
        if (string.IsNullOrEmpty(value))
            return null;
        var s = value.Replace('-', '+').Replace('_', '/');
        s = s.PadRight(s.Length + (4 - s.Length % 4) % 4, '=');
        try
        {
            return Convert.FromBase64String(s);
        }
        catch (FormatException)
        {
            return null;
        }
    }
}
