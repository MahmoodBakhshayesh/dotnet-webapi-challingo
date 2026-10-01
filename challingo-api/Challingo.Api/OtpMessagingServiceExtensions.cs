using Microsoft.Extensions.Options;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Services;
using Challingo.Core.Settings;
using Challingo.Infrastructure.Email;
using Challingo.Infrastructure.Messaging;
using Challingo.Infrastructure.Repositories;

namespace Challingo.Api;

public static class OtpMessagingServiceExtensions
{
    public static WebApplicationBuilder AddOtpAndAuthServices(this WebApplicationBuilder builder)
    {
        builder.Services.Configure<AuthOptions>(builder.Configuration.GetSection("Auth"));
        builder.Services.Configure<OtpOptions>(builder.Configuration.GetSection("Otp"));
        builder.Services.Configure<SmsOptions>(builder.Configuration.GetSection("Sms"));
        builder.Services.Configure<EmailOptions>(builder.Configuration.GetSection("Email"));
        builder.Services.Configure<RabbitMqOptions>(builder.Configuration.GetSection("RabbitMq"));
        builder.Services.Configure<GoogleAuthOptions>(builder.Configuration.GetSection("Google"));
        builder.Services.PostConfigure<GoogleAuthOptions>(options =>
        {
            if (string.IsNullOrWhiteSpace(options.ClientId))
            {
                var env = Environment.GetEnvironmentVariable("Google__ClientId")
                    ?? Environment.GetEnvironmentVariable("GOOGLE_CLIENT_ID");
                if (!string.IsNullOrWhiteSpace(env))
                    options.ClientId = env;
            }

            options.ClientId = GoogleAuthOptions.NormalizeClientIdList(options.ClientId);
        });

        builder.Services.AddScaffoldEmail();
        builder.Services.AddScaffoldMessagingOptions();

        builder.Services.AddTransient<IPhoneOtpRepository, PhoneOtpRepository>();
        builder.Services.AddTransient<IPhoneAuthRepository, PhoneAuthRepository>();
        builder.Services.AddTransient<IOtpService, OtpService>();
        builder.Services.AddTransient<IAuthSessionService, AuthSessionService>();
        builder.Services.AddTransient<IEmailAuthService, EmailAuthService>();
        builder.Services.AddTransient<IPhoneAuthService, PhoneAuthService>();

        return builder;
    }

    public static WebApplication LogGoogleSignInConfiguration(this WebApplication app)
    {
        var googleOptions = app.Services.GetRequiredService<IOptions<GoogleAuthOptions>>().Value;
        var count = googleOptions.GetAudienceClientIds().Length;
        if (count > 0)
        {
            app.Logger.LogInformation("Google Sign-In configured with {Count} client ID(s)", count);
        }
        else
        {
            app.Logger.LogInformation("Google Sign-In is not configured (set Google__ClientId)");
        }

        return app;
    }
}
