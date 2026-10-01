using Challingo.Core.Settings;
using Challingo.Infrastructure;
using Challingo.Infrastructure.DbContexts;
using Challingo.Infrastructure.Email;
using Challingo.Infrastructure.Realtime;
using Challingo.Infrastructure.Redis;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace Challingo.Worker;

public static class DependencyInjection
{
    public static HostApplicationBuilder AddWorkerServices(this HostApplicationBuilder builder)
    {
        builder.Services.Configure<HostOptions>(options =>
        {
            options.BackgroundServiceExceptionBehavior = BackgroundServiceExceptionBehavior.Ignore;
        });

        var connectionString = ResolveDatabaseConnectionString(builder.Configuration);
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            Console.Error.WriteLine(
                "FATAL: ConnectionStrings:Database is missing. " +
                "Set ConnectionStrings__Database in server-files/.env (run sync-server-env.ps1).");
            Environment.Exit(1);
        }

        builder.Services.AddDbContext<AppDbContext>(options =>
        {
            options.UseNpgsql(connectionString, npgsql =>
                npgsql.MigrationsAssembly(typeof(AppDbContext).Assembly.GetName().Name));
        });

        builder.Services.Configure<OtpOptions>(builder.Configuration.GetSection("Otp"));
        builder.Services.Configure<SmsOptions>(builder.Configuration.GetSection("Sms"));
        builder.Services.Configure<EmailOptions>(builder.Configuration.GetSection("Email"));
        builder.Services.Configure<RabbitMqOptions>(builder.Configuration.GetSection("RabbitMq"));
        builder.Services.Configure<WorkerMessagingOptions>(builder.Configuration.GetSection("Worker"));
        builder.Services.Configure<HttpResilienceOptions>(builder.Configuration.GetSection("Http"));

        builder.Services.AddWorkerEmailDelivery();
        builder.Services.AddWorkerSmsDelivery(builder.Configuration);

        // Leaderboards + cache (Redis__Enabled) and pushes to SignalR clients through the Redis backplane.
        builder.Services.AddScaffoldRedis(builder.Configuration);
        builder.Services.AddScaffoldRealtimePublisher(builder.Configuration);

        // Game engine (to generate scheduled puzzles) and competition jobs.
        builder.Services.AddChallingoGameEngine(AppContext.BaseDirectory);
        builder.Services.AddChallingoCompetition();

        return builder;
    }

    private static string? ResolveDatabaseConnectionString(IConfiguration configuration)
    {
        var fromConfig = configuration.GetConnectionString("Database")
            ?? configuration["ConnectionStrings:Database"];
        var fromEnv = Environment.GetEnvironmentVariable("ConnectionStrings__Database");
        var value = (fromConfig ?? fromEnv)?.Trim();
        return string.IsNullOrWhiteSpace(value) ? null : value;
    }
}
