using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;
using Challingo.Infrastructure.Email;

namespace Challingo.Infrastructure.Messaging;

public static class MessagingServiceCollectionExtensions
{
    public static IServiceCollection AddOtpSmsQueuePublishers(this IServiceCollection services)
    {
        services.AddSingleton<LoggingOtpSmsQueuePublisher>();
        services.AddSingleton<RabbitMqOtpSmsQueuePublisher>();
        services.AddSingleton<IOtpSmsQueuePublisher>(sp =>
        {
            var rabbit = sp.GetRequiredService<IOptions<RabbitMqOptions>>().Value;
            return rabbit.Enabled
                ? sp.GetRequiredService<RabbitMqOtpSmsQueuePublisher>()
                : sp.GetRequiredService<LoggingOtpSmsQueuePublisher>();
        });
        return services;
    }

    public static IServiceCollection AddScaffoldMessagingOptions(this IServiceCollection services)
    {
        services.AddOtpSmsQueuePublishers();
        return services;
    }
}
