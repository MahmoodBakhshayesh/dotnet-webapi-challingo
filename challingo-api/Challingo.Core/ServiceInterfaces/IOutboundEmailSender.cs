using Challingo.Core.Messaging;

namespace Challingo.Core.ServiceInterfaces;

public interface IOutboundEmailSender
{
    Task SendAsync(OutboundEmailMessage message, CancellationToken ct = default);
}
