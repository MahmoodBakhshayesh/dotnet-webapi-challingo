namespace Challingo.Core.Settings;

/// <summary>
/// Redis (env: Redis__*). When disabled, leaderboards / distributed cache fall back to
/// in-process memory — fine for a single local API, not for API + Worker in production.
/// </summary>
public sealed class RedisOptions
{
    public bool Enabled { get; set; }

    /// <summary>StackExchange.Redis connection string, e.g. <c>redis:6379,password=...,abortConnect=false</c>.</summary>
    public string ConnectionString { get; set; } = "127.0.0.1:6379,abortConnect=false";

    /// <summary>Key prefix so several projects can share one Redis instance.</summary>
    public string InstanceName { get; set; } = "projectname:";
}
