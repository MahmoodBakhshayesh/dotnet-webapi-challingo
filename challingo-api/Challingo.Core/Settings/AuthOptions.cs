namespace Challingo.Core.Settings;

/// <summary>Feature flags for auth endpoints (env: Auth__EnableEmailAuth, etc.).</summary>
public sealed class AuthOptions
{
    public bool EnablePasswordLogin { get; set; } = true;
    public bool EnableEmailAuth { get; set; } = true;
    public bool EnablePhoneAuth { get; set; } = true;

    /// <summary>Per-IP fixed window for /api/auth OTP endpoints.</summary>
    public int OtpRateLimitPerMinute { get; set; } = 10;

    /// <summary>
    /// First admin email seeded on startup. Set at project create (Auth__SeedAdminEmail).
    /// Local-dev defaults live only in appsettings.Development.json — never in Production.
    /// </summary>
    public string? SeedAdminEmail { get; set; }

    /// <summary>
    /// First admin password seeded on startup. Set at project create (Auth__SeedAdminPassword).
    /// Local-dev defaults live only in appsettings.Development.json — never in Production.
    /// </summary>
    public string? SeedAdminPassword { get; set; }
}
