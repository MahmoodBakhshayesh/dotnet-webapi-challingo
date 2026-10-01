namespace Challingo.Core.Settings;

/// <summary>Optional Idempotency-Key support for mutating requests (env: Idempotency__*).</summary>
public sealed class IdempotencyOptions
{
    public bool Enabled { get; set; } = false;

    /// <summary>How long to remember a key (hours).</summary>
    public int TtlHours { get; set; } = 24;

    /// <summary>Header name clients send (default Idempotency-Key).</summary>
    public string HeaderName { get; set; } = "Idempotency-Key";

    /// <summary>Skip caching responses larger than this many bytes.</summary>
    public int MaxBodyBytes { get; set; } = 1_048_576;
}
