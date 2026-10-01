using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;
using StackExchange.Redis;

namespace Challingo.Infrastructure.Realtime;

public static class RealtimeServiceCollectionExtensions
{
    /// <summary>
    /// SignalR server services + <see cref="IRealtimeNotifier"/>. With Redis__Enabled=true the Redis backplane
    /// is added, so API replicas share groups and the Worker can push to clients. Call after AddScaffoldRedis.
    /// </summary>
    public static ISignalRServerBuilder AddScaffoldSignalR(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<RealtimeOptions>().BindConfiguration("Realtime");
        var realtime = configuration.GetSection("Realtime").Get<RealtimeOptions>() ?? new RealtimeOptions();
        var redis = configuration.GetSection("Redis").Get<RedisOptions>() ?? new RedisOptions();

        var signalR = services.AddSignalR(options =>
        {
            options.KeepAliveInterval = TimeSpan.FromSeconds(Math.Clamp(realtime.KeepAliveSeconds, 5, 120));
            options.ClientTimeoutInterval = TimeSpan.FromSeconds(Math.Clamp(realtime.ClientTimeoutSeconds, 10, 300));
            options.EnableDetailedErrors = realtime.EnableDetailedErrors;
        });

        if (redis.Enabled)
        {
            signalR.AddStackExchangeRedis(redis.ConnectionString, options =>
            {
                // Same prefix in API and Worker, distinct per project when Redis is shared.
                options.Configuration.ChannelPrefix = RedisChannel.Literal($"{redis.InstanceName}signalr");
                options.Configuration.AbortOnConnectFail = false;
            });
        }

        services.AddSingleton<IRealtimeNotifier, HubRealtimeNotifier>();
        return signalR;
    }

    /// <summary>
    /// Worker: push to clients through the Redis backplane. Without Redis there is no path to the API,
    /// so events are logged and dropped.
    /// </summary>
    public static IServiceCollection AddScaffoldRealtimePublisher(this IServiceCollection services, IConfiguration configuration)
    {
        if (configuration.GetValue("Redis:Enabled", false))
            services.AddScaffoldSignalR(configuration);
        else
            services.AddSingleton<IRealtimeNotifier, LoggingRealtimeNotifier>();
        return services;
    }
}
