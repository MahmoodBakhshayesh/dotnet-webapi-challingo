using RabbitMQ.Client;
using Challingo.Core.Settings;

namespace Challingo.Infrastructure.Messaging;

public static class RabbitMqQueueHelper
{
    public static async Task DeclareMainQueueWithDeadLetterAsync(
        IChannel channel,
        RabbitMqOptions cfg,
        string mainQueue,
        string deadLetterQueue,
        CancellationToken ct)
    {
        await channel.QueueDeclareAsync(
            deadLetterQueue,
            durable: true,
            exclusive: false,
            autoDelete: false,
            cancellationToken: ct);

        var args = new Dictionary<string, object?>
        {
            ["x-dead-letter-exchange"] = "",
            ["x-dead-letter-routing-key"] = deadLetterQueue
        };

        await channel.QueueDeclareAsync(
            mainQueue,
            durable: true,
            exclusive: false,
            autoDelete: false,
            arguments: args,
            cancellationToken: ct);
    }

    public static async Task PublishToDeadLetterAsync(
        IChannel channel,
        string deadLetterQueue,
        byte[] body,
        CancellationToken ct)
    {
        var props = new BasicProperties
        {
            Persistent = true,
            ContentType = "application/json"
        };
        await channel.BasicPublishAsync("", deadLetterQueue, false, props, body, ct);
    }
}
