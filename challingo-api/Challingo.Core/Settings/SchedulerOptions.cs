namespace Challingo.Core.Settings;

/// <summary>
/// Quartz scheduler in the Worker (env: Scheduler__*). Each job reads
/// <c>Scheduler__Jobs__{Name}__Enabled</c> and <c>Scheduler__Jobs__{Name}__Cron</c>.
/// RAM job store — run a single Worker replica, and keep jobs idempotent (catch up on missed runs).
/// </summary>
public sealed class SchedulerOptions
{
    public bool Enabled { get; set; } = true;
    public Dictionary<string, ScheduledJobOptions> Jobs { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}

public sealed class ScheduledJobOptions
{
    public bool? Enabled { get; set; }

    /// <summary>Quartz cron (seconds first), e.g. <c>0 0 * * * ?</c> = top of every hour (UTC).</summary>
    public string? Cron { get; set; }
}
