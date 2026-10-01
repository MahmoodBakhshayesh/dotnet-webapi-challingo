using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;
using Challingo.Infrastructure.Realtime;
using Challingo.Infrastructure.Redis;
using StackExchange.Redis;

namespace Challingo.Api.Extensions;

public static class RealtimeExtensions
{
    /// <summary>Redis (cache, leaderboards, backplane connection) — in-memory fallbacks when Redis__Enabled=false.</summary>
    public static WebApplicationBuilder AddScaffoldRedis(this WebApplicationBuilder builder)
    {
        builder.Services.AddScaffoldRedis(builder.Configuration);

        if (builder.Configuration.GetValue("Redis:Enabled", false) && builder.Configuration.GetValue("Health:Enabled", true))
        {
            builder.Services.AddHealthChecks().AddCheck<RedisHealthCheck>("redis", tags: ["ready"]);
        }

        return builder;
    }

    /// <summary>SignalR hub + <see cref="IRealtimeNotifier"/>. Map with <see cref="MapScaffoldRealtime"/>.</summary>
    public static WebApplicationBuilder AddScaffoldRealtime(this WebApplicationBuilder builder)
    {
        var realtime = builder.Configuration.GetSection("Realtime").Get<RealtimeOptions>() ?? new RealtimeOptions();
        if (!realtime.Enabled)
        {
            builder.Services.AddSingleton<IRealtimeNotifier, LoggingRealtimeNotifier>();
            return builder;
        }

        builder.Services.AddScaffoldSignalR(builder.Configuration);
        builder.Services.AddSingleton<IUserIdProvider, SubClaimUserIdProvider>();

        // Browsers and most SignalR clients cannot set headers on WebSocket upgrades: accept ?access_token= on the hub path only.
        builder.Services.PostConfigure<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme, options =>
        {
            var previous = options.Events?.OnMessageReceived;
            options.Events ??= new JwtBearerEvents();
            options.Events.OnMessageReceived = async context =>
            {
                if (previous is not null)
                    await previous(context);

                var accessToken = context.Request.Query["access_token"];
                if (string.IsNullOrEmpty(context.Token)
                    && !string.IsNullOrEmpty(accessToken)
                    && context.HttpContext.Request.Path.StartsWithSegments(realtime.HubPath))
                {
                    context.Token = accessToken;
                }
            };
        });

        return builder;
    }

    public static WebApplication MapScaffoldRealtime(this WebApplication app)
    {
        var realtime = app.Configuration.GetSection("Realtime").Get<RealtimeOptions>() ?? new RealtimeOptions();
        if (!realtime.Enabled)
            return app;

        // Hub connections are long-lived: exempt from the default request timeout.
        app.MapHub<AppHub>(realtime.HubPath).DisableRequestTimeout();
        return app;
    }

    /// <summary>Scaffold tokens carry the user id in <c>sub</c>; fall back to NameIdentifier when inbound claims are mapped.</summary>
    private sealed class SubClaimUserIdProvider : IUserIdProvider
    {
        public string? GetUserId(HubConnectionContext connection) =>
            connection.User?.FindFirst("sub")?.Value
            ?? connection.User?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
    }
}

public sealed class RedisHealthCheck(IConnectionMultiplexer redis) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            var latency = await redis.GetDatabase().PingAsync();
            return HealthCheckResult.Healthy($"Redis ping {latency.TotalMilliseconds:0.#} ms");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Redis unreachable", ex);
        }
    }
}
