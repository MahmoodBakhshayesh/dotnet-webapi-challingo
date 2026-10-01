namespace Challingo.Core.Settings;

/// <summary>Rewarded ads and Plus (env: Monetization__*).</summary>
public sealed class MonetizationOptions
{
    /// <summary>Rewarded ads that count per UTC day.</summary>
    public int AdsPerDay { get; set; } = 3;

    /// <summary>Extra ranked runs per rewarded ad.</summary>
    public int RunsPerAd { get; set; } = 1;

    /// <summary>Stars per rewarded ad.</summary>
    public int StarsPerAd { get; set; } = 5;

    /// <summary>Lets the app grant test ad rewards and test Plus without AdMob/RevenueCat. Never true in production.</summary>
    public bool AllowDevRewards { get; set; }

    public AdMobOptions AdMob { get; set; } = new();
    public RevenueCatOptions RevenueCat { get; set; } = new();
}

public sealed class AdMobOptions
{
    /// <summary>Google's public keys for server-side verification callbacks.</summary>
    public string VerifierKeysUrl { get; set; } = "https://www.gstatic.com/admob/reward/verifier-keys.json";

    /// <summary>Comma-separated rewarded ad unit ids to accept (empty = any of this app's units).</summary>
    public string AllowedAdUnits { get; set; } = "";
}

public sealed class RevenueCatOptions
{
    /// <summary>The exact Authorization header value set on the webhook in the RevenueCat dashboard.</summary>
    public string WebhookAuthorization { get; set; } = "";

    /// <summary>Secret API key (sk_…) used to read subscriber records.</summary>
    public string SecretApiKey { get; set; } = "";

    public string ApiBaseUrl { get; set; } = "https://api.revenuecat.com/v1/";

    /// <summary>The entitlement identifier configured in RevenueCat.</summary>
    public string EntitlementId { get; set; } = "plus";

    public bool Configured => !string.IsNullOrWhiteSpace(SecretApiKey);
}
