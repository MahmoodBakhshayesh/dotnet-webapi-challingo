namespace Challingo.Core.Settings;

/// <summary>Worker-only delivery toggles (env: Worker__EnableEmailDelivery, Worker__EnableSmsOtpDelivery).</summary>
public sealed class WorkerMessagingOptions
{
    public bool EnableEmailDelivery { get; set; }
    public bool EnableSmsOtpDelivery { get; set; }
}
