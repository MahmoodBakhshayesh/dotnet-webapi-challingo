namespace Challingo.Core.Messaging;

public sealed class OtpSmsMessage
{
    public string PhoneNumber { get; init; } = "";
    public string Code { get; init; } = "";
}
