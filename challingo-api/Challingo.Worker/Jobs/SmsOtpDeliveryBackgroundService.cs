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

public sealed class SmsOtpDeliveryBackgroundService(
    IServiceProvider services,
    IOptions<RabbitMqOptions> rabbitOptions,
    IOptions<OtpOptions> otpOptions,
    IOptions<SmsOptions> smsOptions,
    IOptions<WorkerMessagingOptions> workerOptions,
    ILogger<SmsOtpDeliveryBackgroundService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var rabbit = rabbitOptions.Value;
        var worker = workerOptions.Value;

        if (!worker.EnableSmsOtpDelivery)
        {
            logger.LogInformation("SMS OTP worker idle: Worker__EnableSmsOtpDelivery=false");
            return;
        }

        if (!rabbit.Enabled)
        {
            logger.LogInformation("SMS OTP worker idle: RabbitMq__Enabled=false");
            return;
        }

        if (otpOptions.Value.LogOnly)
        {
            logger.LogInformation("SMS OTP worker idle: Otp__LogOnly=true");
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
                await RunConsumerAsync(factory, rabbit, smsOptions.Value, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "SMS OTP consumer faulted; retrying in 10s");
                await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
            }
        }
    }

    private async Task RunConsumerAsync(
        ConnectionFactory factory,
        RabbitMqOptions rabbit,
        SmsOptions sms,
        CancellationToken stoppingToken)
    {
        await using var connection = await factory.CreateConnectionAsync(stoppingToken);
        await using var channel = await connection.CreateChannelAsync(cancellationToken: stoppingToken);

        await RabbitMqQueueHelper.DeclareMainQueueWithDeadLetterAsync(
            channel,
            rabbit,
            rabbit.SmsOtpQueueName,
            rabbit.SmsOtpDeadLetterQueueName,
            stoppingToken);

        await channel.BasicQosAsync(0, 1, false, stoppingToken);

        var consumer = new AsyncEventingBasicConsumer(channel);
        consumer.ReceivedAsync += async (_, args) =>
        {
            var body = args.Body.ToArray();
            try
            {
                var json = Encoding.UTF8.GetString(body);
                var message = JsonSerializer.Deserialize<OtpSmsMessage>(json);
                if (message == null || string.IsNullOrWhiteSpace(message.PhoneNumber))
                {
                    logger.LogWarning("Skipped invalid SMS OTP payload");
                    await channel.BasicAckAsync(args.DeliveryTag, false, stoppingToken);
                    return;
                }

                await using var scope = services.CreateAsyncScope();
                var sender = scope.ServiceProvider.GetRequiredService<ISmsSender>();
                var useSmsIr = sms.Provider.Equals("SmsIr", StringComparison.OrdinalIgnoreCase)
                    && !string.IsNullOrWhiteSpace(sms.SmsIrApiKey);

                if (useSmsIr && sms.SmsIrVerifyTemplateId is > 0)
                    await sender.SendOtpAsync(message.PhoneNumber, message.Code, stoppingToken);
                else
                {
                    var text = sms.OtpMessageTemplate.Replace("{code}", message.Code, StringComparison.Ordinal);
                    await sender.SendAsync(message.PhoneNumber, text, stoppingToken);
                }

                await channel.BasicAckAsync(args.DeliveryTag, false, stoppingToken);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to send SMS OTP; moving to dead-letter queue");
                await RabbitMqQueueHelper.PublishToDeadLetterAsync(
                    channel,
                    rabbit.SmsOtpDeadLetterQueueName,
                    body,
                    stoppingToken);
                await channel.BasicAckAsync(args.DeliveryTag, false, stoppingToken);
            }
        };

        await channel.BasicConsumeAsync(
            rabbit.SmsOtpQueueName,
            autoAck: false,
            consumer: consumer,
            cancellationToken: stoppingToken);

        logger.LogInformation("SMS OTP consumer listening on {Queue}", rabbit.SmsOtpQueueName);
        await Task.Delay(Timeout.Infinite, stoppingToken);
    }
}
