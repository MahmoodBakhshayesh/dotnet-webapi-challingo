namespace Challingo.Core.Settings;

/// <summary>Global API rate limiting (env: RateLimit__*). Auth OTP uses Auth__OtpRateLimitPerMinute.</summary>
public sealed class RateLimitOptions
{
    public bool Enabled { get; set; } = true;

    /// <summary>Per IP (or authenticated user) requests allowed per minute for all endpoints.</summary>
    public int GlobalPerMinute { get; set; } = 120;
}
