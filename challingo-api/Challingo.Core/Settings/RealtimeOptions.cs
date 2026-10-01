namespace Challingo.Core.Settings;

/// <summary>SignalR (env: Realtime__*). Scale-out uses the Redis backplane when Redis__Enabled=true.</summary>
public sealed class RealtimeOptions
{
    public bool Enabled { get; set; } = true;
    public string HubPath { get; set; } = "/hubs/app";

    public int KeepAliveSeconds { get; set; } = 15;
    public int ClientTimeoutSeconds { get; set; } = 30;
    public bool EnableDetailedErrors { get; set; }
}
