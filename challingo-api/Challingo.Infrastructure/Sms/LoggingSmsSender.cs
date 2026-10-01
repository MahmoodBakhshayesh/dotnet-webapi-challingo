using Microsoft.Extensions.Logging;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Infrastructure.Sms;

public sealed class LoggingSmsSender(ILogger<LoggingSmsSender> logger) : ISmsSender
{
    public Task SendAsync(string phoneNumber, string message, CancellationToken ct = default)
    {
        logger.LogInformation("[SMS LogOnly] To {Phone}: {Message}", phoneNumber, message);
        return Task.CompletedTask;
    }

    public Task SendOtpAsync(string phoneNumber, string code, CancellationToken ct = default)
    {
        logger.LogInformation("[SMS LogOnly OTP] To {Phone}: {Code}", phoneNumber, code);
        return Task.CompletedTask;
    }
}
