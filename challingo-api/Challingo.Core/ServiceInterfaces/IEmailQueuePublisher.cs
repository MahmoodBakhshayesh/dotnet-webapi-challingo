using Challingo.Core.Messaging;

namespace Challingo.Core.ServiceInterfaces;

public interface IEmailQueuePublisher
{
    Task PublishAsync(OutboundEmailMessage message, CancellationToken ct = default);
}
