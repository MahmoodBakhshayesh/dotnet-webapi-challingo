using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;
using Challingo.Core.Messaging;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;
using Challingo.Infrastructure.Messaging;

namespace Challingo.Infrastructure.Email;

public sealed class LoggingEmailQueuePublisher(ILogger<LoggingEmailQueuePublisher> logger) : IEmailQueuePublisher
{
    public Task PublishAsync(OutboundEmailMessage message, CancellationToken ct = default)
    {
        logger.LogInformation(
            "Email queued (log-only): to={To} subject={Subject} kind={Kind}",
            message.To,
            message.Subject,
            message.Kind);
        return Task.CompletedTask;
    }
}

public sealed class RabbitMqEmailQueuePublisher(
    IOptions<RabbitMqOptions> options,
    ILogger<RabbitMqEmailQueuePublisher> logger) : IEmailQueuePublisher
{
    public async Task PublishAsync(OutboundEmailMessage message, CancellationToken ct = default)
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
            cfg.EmailQueueName,
            cfg.EmailDeadLetterQueueName,
            ct);

        var body = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(message));
        var props = new BasicProperties
        {
            Persistent = true,
            ContentType = "application/json"
        };
        await channel.BasicPublishAsync("", cfg.EmailQueueName, false, props, body, ct);

        logger.LogDebug("Published email to {Queue} for {To}", cfg.EmailQueueName, message.To);
    }
}
