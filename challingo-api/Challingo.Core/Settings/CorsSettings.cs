namespace Challingo.Core.Settings;

/// <summary>Browser CORS origins (env: Cors__AllowedOrigins__0, ...).</summary>
public sealed class CorsSettings
{
    public string[] AllowedOrigins { get; set; } = [];
}
