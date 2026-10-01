namespace Challingo.Core.Settings;

public sealed class JwtAuthOptions
{
    public required string Issuer { get; set; }
    public required string Audience { get; set; }
    public required string Key { get; set; }
    public int ExpirationInMinutes { get; set; }
    public int RefreshTokenExpirationDays { get; set; }
}
