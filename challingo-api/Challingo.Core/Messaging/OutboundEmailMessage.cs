namespace Challingo.Core.Messaging;

public sealed class OutboundEmailMessage
{
    public string To { get; init; } = "";
    public string Subject { get; init; } = "";
    public string HtmlBody { get; init; } = "";
    public string? TextBody { get; init; }
    public string Kind { get; init; } = "generic";
}
