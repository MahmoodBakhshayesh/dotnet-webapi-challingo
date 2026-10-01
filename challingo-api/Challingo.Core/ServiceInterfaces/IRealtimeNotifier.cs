namespace Challingo.Core.ServiceInterfaces;

/// <summary>
/// Pushes events to connected SignalR clients. In the API it writes to the hub directly;
/// in the Worker it publishes over Redis and the API relays (requires Redis__Enabled=true).
/// Clients listen with <c>connection.on(method, ...)</c>.
/// </summary>
public interface IRealtimeNotifier
{
    Task ToUserAsync(string userId, string method, object? payload, CancellationToken ct = default);
    Task ToGroupAsync(string group, string method, object? payload, CancellationToken ct = default);
    Task ToAllAsync(string method, object? payload, CancellationToken ct = default);
}
