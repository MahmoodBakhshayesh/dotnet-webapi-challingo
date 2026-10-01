namespace Challingo.Core.Settings;

/// <summary>Inbound ASP.NET request timeout (env: RequestTimeout__*).</summary>
public sealed class ScaffoldRequestTimeoutOptions
{
    public bool Enabled { get; set; } = true;

    /// <summary>Default timeout for API requests (health/swagger exempt).</summary>
    public int Seconds { get; set; } = 30;
}
