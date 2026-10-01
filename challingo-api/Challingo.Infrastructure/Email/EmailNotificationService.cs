using Microsoft.Extensions.Options;
using Challingo.Core.Messaging;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Infrastructure.Email;

public sealed class EmailNotificationService(
    IEmailQueuePublisher queue,
    IOptions<EmailOptions> emailOptions) : IEmailNotificationService
{
    public Task QueueAsync(string toEmail, string subject, string htmlBody, CancellationToken ct = default)
    {
        if (!emailOptions.Value.Enabled)
            return Task.CompletedTask;

        return queue.PublishAsync(new OutboundEmailMessage
        {
            To = toEmail.Trim(),
            Subject = subject,
            HtmlBody = htmlBody,
            Kind = "notification"
        }, ct);
    }
}
