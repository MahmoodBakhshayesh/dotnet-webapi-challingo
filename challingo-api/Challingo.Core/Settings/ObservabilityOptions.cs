namespace Challingo.Core.Settings;

/// <summary>Optional compose profile (Seq + Uptime Kuma). Env: Observability__Enabled.</summary>
public sealed class ObservabilityOptions
{
    public bool Enabled { get; set; }
}
