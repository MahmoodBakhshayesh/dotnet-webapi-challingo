using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using Challingo.Core.Realtime;

namespace Challingo.Infrastructure.Realtime;

/// <summary>
/// Single app-wide hub (Realtime:HubPath, default <c>/hubs/app</c>). Clients connect with
/// <c>?access_token=JWT</c>; each connection joins <c>user:{id}</c> automatically and can
/// subscribe to topic groups such as <c>challenge:{id}</c> or <c>leaderboard:daily</c>.
/// Server → client pushes go through <see cref="Challingo.Core.ServiceInterfaces.IRealtimeNotifier"/>.
/// Lives in Infrastructure (not Api) so the Worker can publish to it through the Redis backplane —
/// the backplane identifies hubs by type name, so both processes must share this type.
/// </summary>
[Authorize]
public sealed partial class AppHub(ILogger<AppHub> logger) : Hub
{
    public override async Task OnConnectedAsync()
    {
        if (Context.UserIdentifier is { } userId)
            await Groups.AddToGroupAsync(Context.ConnectionId, RealtimeGroups.User(userId));

        await base.OnConnectedAsync();
    }

    /// <summary>Join a topic group. <c>user:*</c> groups are reserved for server-side targeting.</summary>
    public async Task Subscribe(string topic)
    {
        EnsureValidTopic(topic);
        await Groups.AddToGroupAsync(Context.ConnectionId, topic);
        logger.LogDebug("Connection {ConnectionId} subscribed to {Topic}", Context.ConnectionId, topic);
    }

    public async Task Unsubscribe(string topic)
    {
        EnsureValidTopic(topic);
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, topic);
    }

    /// <summary>Round-trip check and server clock for the client (never trust device time for gameplay).</summary>
    public DateTimeOffset Ping() => DateTimeOffset.UtcNow;

    private static void EnsureValidTopic(string topic)
    {
        if (string.IsNullOrWhiteSpace(topic) || !TopicPattern().IsMatch(topic) || topic.StartsWith("user:", StringComparison.OrdinalIgnoreCase))
            throw new HubException("Invalid topic.");
    }

    [GeneratedRegex("^[a-z0-9][a-z0-9:_\\-.]{0,99}$")]
    private static partial Regex TopicPattern();
}
