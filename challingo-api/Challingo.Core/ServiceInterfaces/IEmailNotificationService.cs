namespace Challingo.Core.ServiceInterfaces;

public interface IEmailNotificationService
{
    Task QueueAsync(string toEmail, string subject, string htmlBody, CancellationToken ct = default);
}
