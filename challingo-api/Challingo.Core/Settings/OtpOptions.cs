namespace Challingo.Core.Settings;

public sealed class OtpOptions
{
    /// <summary>When true, OTP code is logged to console (dev).</summary>
    public bool DevMode { get; set; } = true;

    /// <summary>When true, SMS is not sent (LogOnly sender).</summary>
    public bool LogOnly { get; set; } = true;

    public int MaxVerifyAttempts { get; set; } = 5;
}
