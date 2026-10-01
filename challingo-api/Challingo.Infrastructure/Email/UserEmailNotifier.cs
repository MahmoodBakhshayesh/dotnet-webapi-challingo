using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Challingo.Core.ServiceInterfaces;
using Challingo.Infrastructure.DbContexts;

namespace Challingo.Infrastructure.Email;

public sealed class UserEmailNotifier(
    AppDbContext db,
    IEmailNotificationService emailNotifications,
    ILogger<UserEmailNotifier> logger) : IUserEmailNotifier
{
    public async Task NotifyUserAsync(
        Guid userId,
        string subject,
        string htmlBody,
        CancellationToken ct = default)
    {
        var user = await db.Users.AsNoTracking()
            .Where(u => u.Id == userId)
            .Select(u => new { u.Email, u.EmailConfirmed })
            .FirstOrDefaultAsync(ct);

        if (user == null || string.IsNullOrWhiteSpace(user.Email) || !user.EmailConfirmed)
            return;

        try
        {
            await emailNotifications.QueueAsync(user.Email, subject, htmlBody, ct);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Failed to queue email notification for user {UserId}", userId);
        }
    }
}
