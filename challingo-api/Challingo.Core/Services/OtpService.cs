using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.Enums;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.Messaging;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services;

/// <summary>Stores OTP challenges and enqueues delivery to the worker (no direct SMS/email send).</summary>
public sealed class OtpService(
    IPhoneOtpRepository otpRepository,
    IEmailQueuePublisher emailQueue,
    IOtpSmsQueuePublisher smsQueue,
    IOptions<OtpOptions> otpOptions,
    IOptions<EmailOptions> emailOptions,
    IOptions<RabbitMqOptions> rabbitOptions,
    ILogger<OtpService> logger) : IOtpService
{
    public async Task SendOtpAsync(string channelKey, Guid? userId = null, CancellationToken ct = default)
    {
        var code = Random.Shared.Next(100000, 999999).ToString();
        var challenge = new PhoneOtpChallenge
        {
            Id = Guid.CreateVersion7(),
            PhoneNumber = channelKey,
            CodeHash = OtpHash.Hash(code),
            ExpiresAtUtc = DateTime.UtcNow.AddMinutes(5),
            Status = OtpChallengeStatus.Pending,
            UserId = userId,
            CreatedAt = DateTime.UtcNow
        };
        await otpRepository.AddAsync(challenge, ct);

        if (otpOptions.Value.DevMode)
        {
            logger.LogInformation("OTP for {Channel}: {Code}", channelKey, code);
            Console.WriteLine($"[OTP DevMode] {channelKey} => {code}");
        }

        if (otpOptions.Value.LogOnly)
            return;

        if (!rabbitOptions.Value.Enabled)
        {
            logger.LogWarning(
                "OTP delivery skipped: RabbitMq:Enabled=false. Enable RabbitMQ and worker delivery to send SMS/email.");
            return;
        }

        if (EmailOtpHelper.TryParseEmailFromOtpKey(channelKey, out var emailAddress))
        {
            await QueueEmailOtpAsync(emailAddress, code, ct);
            return;
        }

        await smsQueue.PublishAsync(new OtpSmsMessage { PhoneNumber = channelKey, Code = code }, ct);
    }

    public async Task<bool> VerifyOtpAsync(string channelKey, string code, CancellationToken ct = default)
    {
        var pending = await otpRepository.GetLatestPendingAsync(channelKey, ct);
        if (pending == null)
            return false;
        if (pending.AttemptCount >= otpOptions.Value.MaxVerifyAttempts)
            return false;

        var challenge = await otpRepository.FindValidAsync(channelKey, code, ct);
        if (challenge == null)
        {
            await otpRepository.RecordFailedAttemptAsync(channelKey, ct);
            return false;
        }

        await otpRepository.MarkUsedAsync(challenge, ct);
        return true;
    }

    private async Task QueueEmailOtpAsync(string emailAddress, string code, CancellationToken ct)
    {
        var email = emailOptions.Value;
        if (!email.Enabled)
        {
            if (otpOptions.Value.DevMode)
                logger.LogInformation("Email OTP for {Email}: {Code} (Email:Enabled=false)", emailAddress, code);
            return;
        }

        var html = email.OtpHtmlTemplate.Replace("{code}", code, StringComparison.Ordinal);
        await emailQueue.PublishAsync(new OutboundEmailMessage
        {
            To = emailAddress,
            Subject = email.OtpSubject,
            HtmlBody = html,
            TextBody = $"Your sign-in code is {code}.",
            Kind = "otp"
        }, ct);
    }
}
