using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using Challingo.Core.Messaging;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;
using Challingo.Infrastructure.Messaging;

namespace Challingo.Worker.Jobs;

public sealed class EmailDeliveryBackgroundService(
    IServiceProvider services,
    IOptions<RabbitMqOptions> rabbitOptions,
    IOptions<EmailOptions> emailOptions,
    IOptions<WorkerMessagingOptions> workerOptions,
    ILogger<EmailDeliveryBackgroundService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var rabbit = rabbitOptions.Value;
        var email = emailOptions.Value;
        var worker = workerOptions.Value;

        if (!worker.EnableEmailDelivery)
        {
            logger.LogInformation("Email worker idle: Worker__EnableEmailDelivery=false");
            return;
        }

        if (!rabbit.Enabled)
        {
            logger.LogInformation("Email worker idle: RabbitMq__Enabled=false");
            return;
        }

        if (!email.Enabled)
        {
            logger.LogInformation("Email worker idle: Email__Enabled=false");
            return;
        }

        var factory = new ConnectionFactory
        {
            HostName = rabbit.HostName,
            Port = rabbit.Port,
            UserName = rabbit.UserName,
            Password = rabbit.Password
        };

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await RunConsumerAsync(factory, rabbit, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Email consumer faulted; retrying in 10s");
                await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
            }
        }
    }

    private async Task RunConsumerAsync(
        ConnectionFactory factory,
        RabbitMqOptions rabbit,
        CancellationToken stoppingToken)
    {
        await using var connection = await factory.CreateConnectionAsync(stoppingToken);
        await using var channel = await connection.CreateChannelAsync(cancellationToken: stoppingToken);

        await RabbitMqQueueHelper.DeclareMainQueueWithDeadLetterAsync(
            channel,
            rabbit,
            rabbit.EmailQueueName,
            rabbit.EmailDeadLetterQueueName,
            stoppingToken);

        await channel.BasicQosAsync(0, 1, false, stoppingToken);

        var consumer = new AsyncEventingBasicConsumer(channel);
        consumer.ReceivedAsync += async (_, args) =>
        {
            var body = args.Body.ToArray();
            try
            {
                var json = Encoding.UTF8.GetString(body);
                var message = JsonSerializer.Deserialize<OutboundEmailMessage>(json);
                if (message == null || string.IsNullOrWhiteSpace(message.To))
                {
                    logger.LogWarning("Skipped invalid email message payload");
                    await channel.BasicAckAsync(args.DeliveryTag, false, stoppingToken);
                    return;
                }

                await using var scope = services.CreateAsyncScope();
                var sender = scope.ServiceProvider.GetRequiredService<IOutboundEmailSender>();
                await sender.SendAsync(message, stoppingToken);
                await channel.BasicAckAsync(args.DeliveryTag, false, stoppingToken);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to send email; moving to dead-letter queue");
                await RabbitMqQueueHelper.PublishToDeadLetterAsync(
                    channel,
                    rabbit.EmailDeadLetterQueueName,
                    body,
                    stoppingToken);
                await channel.BasicAckAsync(args.DeliveryTag, false, stoppingToken);
            }
        };

        await channel.BasicConsumeAsync(
            rabbit.EmailQueueName,
            autoAck: false,
            consumer: consumer,
            cancellationToken: stoppingToken);

        logger.LogInformation("Email consumer listening on {Queue}", rabbit.EmailQueueName);
        await Task.Delay(Timeout.Infinite, stoppingToken);
    }
}
