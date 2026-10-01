using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MimeKit;
using Challingo.Core.Messaging;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Infrastructure.Email;

public sealed class GmailSmtpEmailSender(
    IOptions<EmailOptions> options,
    ILogger<GmailSmtpEmailSender> logger) : IOutboundEmailSender
{
    public async Task SendAsync(OutboundEmailMessage message, CancellationToken ct = default)
    {
        var email = options.Value;
        if (!email.Enabled)
        {
            logger.LogWarning("Email send skipped (Email:Enabled=false) for {To}", message.To);
            return;
        }

        if (string.IsNullOrWhiteSpace(email.FromAddress)
            || string.IsNullOrWhiteSpace(email.SmtpUsername)
            || string.IsNullOrWhiteSpace(email.SmtpPassword))
        {
            throw new InvalidOperationException(
                "Email is enabled but FromAddress, SmtpUsername, or SmtpPassword is missing.");
        }

        var mime = new MimeMessage();
        mime.From.Add(new MailboxAddress(email.FromDisplayName, email.FromAddress));
        mime.To.Add(MailboxAddress.Parse(message.To));
        mime.Subject = message.Subject;

        var builder = new BodyBuilder
        {
            HtmlBody = message.HtmlBody,
            TextBody = message.TextBody ?? StripHtml(message.HtmlBody)
        };
        mime.Body = builder.ToMessageBody();

        using var client = new SmtpClient();
        await client.ConnectAsync(email.SmtpHost, email.SmtpPort, SecureSocketOptions.StartTls, ct);
        await client.AuthenticateAsync(email.SmtpUsername, email.SmtpPassword, ct);
        await client.SendAsync(mime, ct);
        await client.DisconnectAsync(true, ct);

        logger.LogInformation("Sent email to {To} subject={Subject}", message.To, message.Subject);
    }

    private static string StripHtml(string html) =>
        string.IsNullOrWhiteSpace(html)
            ? ""
            : System.Text.RegularExpressions.Regex.Replace(html, "<[^>]+>", " ").Trim();
}
