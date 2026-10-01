using Microsoft.Extensions.Logging;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Infrastructure.Realtime;

/// <summary>Worker fallback when Redis is disabled: there is no channel to the API, so events are logged and dropped.</summary>
public sealed class LoggingRealtimeNotifier(ILogger<LoggingRealtimeNotifier> logger) : IRealtimeNotifier
{
    public Task ToUserAsync(string userId, string method, object? payload, CancellationToken ct = default) =>
        Log($"user:{userId}", method);

    public Task ToGroupAsync(string group, string method, object? payload, CancellationToken ct = default) =>
        Log(group, method);

    public Task ToAllAsync(string method, object? payload, CancellationToken ct = default) =>
        Log("all", method);

    private Task Log(string target, string method)
    {
        logger.LogInformation("Realtime event {Method} → {Target} dropped (enable Redis__Enabled to relay from the Worker).", method, target);
        return Task.CompletedTask;
    }
}
