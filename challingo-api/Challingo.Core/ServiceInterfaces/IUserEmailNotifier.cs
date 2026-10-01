namespace Challingo.Core.ServiceInterfaces;

public interface IUserEmailNotifier
{
    Task NotifyUserAsync(Guid userId, string subject, string htmlBody, CancellationToken ct = default);
}
