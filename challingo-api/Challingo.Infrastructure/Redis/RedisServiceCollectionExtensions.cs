using Microsoft.Extensions.Caching.StackExchangeRedis;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;
using Challingo.Infrastructure.Leaderboards;
using StackExchange.Redis;

namespace Challingo.Infrastructure.Redis;

public static class RedisServiceCollectionExtensions
{
    /// <summary>
    /// Redis__Enabled=true → shared <see cref="IConnectionMultiplexer"/>, Redis IDistributedCache, Redis leaderboards.
    /// Otherwise → in-memory cache + in-memory leaderboards (single process only).
    /// Used by both API and Worker.
    /// </summary>
    public static IServiceCollection AddScaffoldRedis(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<RedisOptions>()
            .BindConfiguration("Redis")
            .Validate(o => !o.Enabled || !string.IsNullOrWhiteSpace(o.ConnectionString),
                "Redis:ConnectionString is required when Redis:Enabled=true.")
            .ValidateOnStart();

        var redis = configuration.GetSection("Redis").Get<RedisOptions>() ?? new RedisOptions();
        if (!redis.Enabled)
        {
            services.AddDistributedMemoryCache();
            services.AddSingleton<ILeaderboardStore, InMemoryLeaderboardStore>();
            return services;
        }

        services.AddSingleton<IConnectionMultiplexer>(sp =>
        {
            var config = ConfigurationOptions.Parse(redis.ConnectionString);
            // Keep retrying in the background instead of crashing the host when Redis starts late.
            config.AbortOnConnectFail = false;
            var logger = sp.GetRequiredService<ILoggerFactory>().CreateLogger("Redis");
            var mux = ConnectionMultiplexer.Connect(config);
            mux.ConnectionFailed += (_, e) => logger.LogWarning("Redis connection failed: {Failure} {Endpoint}", e.FailureType, e.EndPoint);
            mux.ConnectionRestored += (_, e) => logger.LogInformation("Redis connection restored: {Endpoint}", e.EndPoint);
            return mux;
        });

        services.AddStackExchangeRedisCache(options => options.InstanceName = redis.InstanceName);
        // Reuse the shared multiplexer instead of letting the cache open its own connection.
        services.AddOptions<RedisCacheOptions>()
            .Configure<IConnectionMultiplexer>((options, mux) =>
                options.ConnectionMultiplexerFactory = () => Task.FromResult(mux));
        services.AddSingleton<ILeaderboardStore, RedisLeaderboardStore>();
        return services;
    }
}
