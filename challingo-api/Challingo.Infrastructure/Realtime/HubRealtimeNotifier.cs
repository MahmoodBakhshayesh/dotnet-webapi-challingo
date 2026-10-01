using Microsoft.AspNetCore.SignalR;
using Challingo.Core.Realtime;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Infrastructure.Realtime;

/// <summary>
/// Sends through <see cref="IHubContext{AppHub}"/>. In the API this reaches local connections and, with Redis,
/// every replica via the backplane. In the Worker it only works through the Redis backplane.
/// </summary>
public sealed class HubRealtimeNotifier(IHubContext<AppHub> hub) : IRealtimeNotifier
{
    // Group-based user targeting behaves the same with or without a backplane and with any IUserIdProvider.
    public Task ToUserAsync(string userId, string method, object? payload, CancellationToken ct = default) =>
        hub.Clients.Group(RealtimeGroups.User(userId)).SendAsync(method, payload, ct);

    public Task ToGroupAsync(string group, string method, object? payload, CancellationToken ct = default) =>
        hub.Clients.Group(group).SendAsync(method, payload, ct);

    public Task ToAllAsync(string method, object? payload, CancellationToken ct = default) =>
        hub.Clients.All.SendAsync(method, payload, ct);
}
