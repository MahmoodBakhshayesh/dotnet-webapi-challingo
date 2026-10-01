namespace Challingo.Core.Settings;

/// <summary>Outbound HttpClient resilience via Microsoft.Extensions.Http.Resilience (env: Http__*).</summary>
public sealed class HttpResilienceOptions
{
    public bool Enabled { get; set; } = true;

    /// <summary>Per-attempt timeout in seconds.</summary>
    public int TimeoutSeconds { get; set; } = 15;

    /// <summary>Max retries on transient failures (0 = no retries).</summary>
    public int RetryCount { get; set; } = 2;

    /// <summary>Base delay for exponential backoff (ms).</summary>
    public int RetryBaseDelayMs { get; set; } = 200;

    /// <summary>Minimum failures in sampling window before circuit may open.</summary>
    public int CircuitBreakFailures { get; set; } = 5;

    /// <summary>How long the circuit stays open (seconds).</summary>
    public int CircuitBreakSeconds { get; set; } = 30;
}
