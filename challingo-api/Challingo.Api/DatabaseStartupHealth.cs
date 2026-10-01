using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace Challingo.Api;

/// <summary>
/// Tracks whether startup migrate/seed left the API in a degraded ready state.
/// </summary>
public sealed class DatabaseStartupHealthState
{
    public bool MigrateFailed { get; set; }
    public string? ErrorMessage { get; set; }
}

public sealed class DatabaseStartupHealthCheck(DatabaseStartupHealthState state) : IHealthCheck
{
    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        if (state.MigrateFailed)
        {
            return Task.FromResult(HealthCheckResult.Unhealthy(
                state.ErrorMessage ?? "Database migrate failed during startup."));
        }

        return Task.FromResult(HealthCheckResult.Healthy());
    }
}
