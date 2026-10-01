using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;
using Challingo.Core.Messaging;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Infrastructure.Messaging;

public sealed class LoggingOtpSmsQueuePublisher(ILogger<LoggingOtpSmsQueuePublisher> logger) : IOtpSmsQueuePublisher
{
    public Task PublishAsync(OtpSmsMessage message, CancellationToken ct = default)
    {
        logger.LogInformation(
            "SMS OTP queued (log-only): phone={Phone}",
            message.PhoneNumber);
        return Task.CompletedTask;
    }
}

public sealed class RabbitMqOtpSmsQueuePublisher(
    IOptions<RabbitMqOptions> options,
    ILogger<RabbitMqOtpSmsQueuePublisher> logger) : IOtpSmsQueuePublisher
{
    public async Task PublishAsync(OtpSmsMessage message, CancellationToken ct = default)
    {
        var cfg = options.Value;
        var factory = new ConnectionFactory
        {
            HostName = cfg.HostName,
            Port = cfg.Port,
            UserName = cfg.UserName,
            Password = cfg.Password
        };

        await using var connection = await factory.CreateConnectionAsync(ct);
        await using var channel = await connection.CreateChannelAsync(cancellationToken: ct);

        await RabbitMqQueueHelper.DeclareMainQueueWithDeadLetterAsync(
            channel,
            cfg,
            cfg.SmsOtpQueueName,
            cfg.SmsOtpDeadLetterQueueName,
            ct);

        var body = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(message));
        var props = new BasicProperties
        {
            Persistent = true,
            ContentType = "application/json"
        };
        await channel.BasicPublishAsync("", cfg.SmsOtpQueueName, false, props, body, ct);

        logger.LogDebug("Published SMS OTP to {Queue} for {Phone}", cfg.SmsOtpQueueName, message.PhoneNumber);
    }
}
