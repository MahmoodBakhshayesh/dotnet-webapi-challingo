using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;
using Challingo.Infrastructure.Http;
using Challingo.Infrastructure.Sms;

namespace Challingo.Infrastructure.Email;

public static class EmailServiceCollectionExtensions
{
    public static IServiceCollection AddScaffoldEmail(this IServiceCollection services)
    {
        services.AddEmailQueuePublishers();
        services.AddTransient<IEmailNotificationService, EmailNotificationService>();
        services.AddTransient<IUserEmailNotifier, UserEmailNotifier>();
        services.AddTransient<IGoogleAuthService, GoogleAuthService>();
        services.AddTransient<IOutboundEmailSender, GmailSmtpEmailSender>();
        return services;
    }

    public static IServiceCollection AddEmailQueuePublishers(this IServiceCollection services)
    {
        services.AddSingleton<LoggingEmailQueuePublisher>();
        services.AddSingleton<RabbitMqEmailQueuePublisher>();
        services.AddSingleton<IEmailQueuePublisher>(sp =>
        {
            var rabbit = sp.GetRequiredService<IOptions<RabbitMqOptions>>().Value;
            return rabbit.Enabled
                ? sp.GetRequiredService<RabbitMqEmailQueuePublisher>()
                : sp.GetRequiredService<LoggingEmailQueuePublisher>();
        });
        return services;
    }

    public static IServiceCollection AddWorkerEmailDelivery(this IServiceCollection services)
    {
        services.AddTransient<IOutboundEmailSender, GmailSmtpEmailSender>();
        return services;
    }

    public static IServiceCollection AddWorkerSmsDelivery(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<HttpResilienceOptions>().BindConfiguration("Http");
        services.AddHttpClient<SmsIrSmsSender>()
            .AddScaffoldHttpResilience(configuration);
        services.AddTransient<LoggingSmsSender>();
        services.AddTransient<ISmsSender>(sp =>
        {
            var sms = sp.GetRequiredService<IOptions<SmsOptions>>().Value;
            var otp = sp.GetRequiredService<IOptions<OtpOptions>>().Value;
            var useSmsIr = !otp.LogOnly
                && sms.Provider.Equals("SmsIr", StringComparison.OrdinalIgnoreCase)
                && !string.IsNullOrWhiteSpace(sms.SmsIrApiKey);
            return useSmsIr
                ? sp.GetRequiredService<SmsIrSmsSender>()
                : sp.GetRequiredService<LoggingSmsSender>();
        });
        return services;
    }
}
