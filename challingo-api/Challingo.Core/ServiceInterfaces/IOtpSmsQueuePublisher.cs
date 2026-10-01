using Challingo.Core.Messaging;

namespace Challingo.Core.ServiceInterfaces;

public interface IOtpSmsQueuePublisher
{
    Task PublishAsync(OtpSmsMessage message, CancellationToken ct = default);
}
