namespace Challingo.Core.Settings;

public sealed class MaintenanceOptions
{
    public bool Enabled { get; set; }
    public string Message { get; set; } = "Service is temporarily unavailable for maintenance.";
    /// <summary>Optional header X-Maintenance-Bypass must match this value.</summary>
    public string? BypassKey { get; set; }
}
