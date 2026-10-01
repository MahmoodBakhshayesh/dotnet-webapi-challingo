using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Http.Timeouts;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;
using Challingo.Core.Settings;
using Challingo.Infrastructure.DbContexts;
using Serilog;
using Serilog.Events;

namespace Challingo.Api.Extensions;

public static class ScaffoldHostExtensions
{
    public static WebApplicationBuilder AddScaffoldHost(this WebApplicationBuilder builder)
    {
        builder.ConfigureSerilog();
        builder.Services.AddOptions<SerilogOptions>().BindConfiguration("Serilog");
        builder.Services.AddOptions<HealthOptions>().BindConfiguration("Health");
        builder.Services.AddOptions<DatabaseOptions>().BindConfiguration("Database");
        builder.Services.AddOptions<MaintenanceOptions>().BindConfiguration("Maintenance");
        builder.Services.AddOptions<StorageOptions>().BindConfiguration("Storage");
        builder.Services.AddOptions<ObservabilityOptions>().BindConfiguration("Observability");
        builder.Services.AddOptions<RateLimitOptions>().BindConfiguration("RateLimit");
        builder.Services.AddOptions<ScaffoldRequestTimeoutOptions>().BindConfiguration("RequestTimeout");
        builder.Services.AddOptions<HttpResilienceOptions>().BindConfiguration("Http");
        builder.Services.AddOptions<IdempotencyOptions>().BindConfiguration("Idempotency");
        builder.Services.AddOptions<CorsSettings>().BindConfiguration("Cors");
        builder.Services.AddOptions<RealtimeOptions>().BindConfiguration("Realtime");
        builder.Services.AddSingleton<DatabaseStartupHealthState>();
        builder.Services.AddMemoryCache();

        builder.AddScaffoldHealthChecks();
        builder.AddScaffoldRateLimiting();
        builder.AddScaffoldRequestTimeouts();
        builder.AddScaffoldOptionsValidation();

        return builder;
    }

    public static void ConfigureSerilog(this WebApplicationBuilder builder)
    {
        var serilog = builder.Configuration.GetSection("Serilog").Get<SerilogOptions>() ?? new SerilogOptions();
        if (!serilog.Enabled)
            return;

        if (!Enum.TryParse<LogEventLevel>(serilog.MinimumLevel, ignoreCase: true, out var minLevel))
            minLevel = LogEventLevel.Information;

        var loggerConfig = new LoggerConfiguration()
            .MinimumLevel.Is(minLevel)
            .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
            .MinimumLevel.Override("Microsoft.AspNetCore", LogEventLevel.Warning)
            .Enrich.FromLogContext()
            .Enrich.WithProperty("Application", "Challingo.Api")
            .WriteTo.Console();

        if (serilog.WriteToFile)
        {
            loggerConfig = loggerConfig.WriteTo.File(
                serilog.FilePath,
                rollingInterval: RollingInterval.Day,
                retainedFileCountLimit: 14);
        }

        Log.Logger = loggerConfig.CreateLogger();
        builder.Host.UseSerilog();
    }

    public static WebApplicationBuilder AddScaffoldHealthChecks(this WebApplicationBuilder builder)
    {
        var health = builder.Configuration.GetSection("Health").Get<HealthOptions>() ?? new HealthOptions();
        if (!health.Enabled)
            return builder;

        var checks = builder.Services.AddHealthChecks()
            .AddDbContextCheck<AppDbContext>("database", tags: ["ready"])
            .AddCheck<DatabaseStartupHealthCheck>("database-startup", tags: ["ready"])
            .AddCheck("live", () => HealthCheckResult.Healthy(), tags: ["live"]);

        if (builder.Configuration.GetValue("RabbitMq:Enabled", false))
        {
            checks.AddCheck(
                "rabbitmq-config",
                () => HealthCheckResult.Healthy("RabbitMQ enabled in configuration"),
                tags: ["ready"]);
        }

        return builder;
    }

    public static WebApplicationBuilder AddScaffoldRateLimiting(this WebApplicationBuilder builder)
    {
        var auth = builder.Configuration.GetSection("Auth").Get<AuthOptions>() ?? new AuthOptions();
        var rate = builder.Configuration.GetSection("RateLimit").Get<RateLimitOptions>() ?? new RateLimitOptions();
        var authPermit = Math.Max(1, auth.OtpRateLimitPerMinute);
        var globalPermit = Math.Max(1, rate.GlobalPerMinute);

        builder.Services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

            options.AddPolicy("auth-otp", httpContext =>
            {
                var key = httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
                return RateLimitPartition.GetFixedWindowLimiter(
                    key,
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = authPermit,
                        Window = TimeSpan.FromMinutes(1),
                        AutoReplenishment = true,
                        QueueLimit = 0
                    });
            });

            if (rate.Enabled)
            {
                options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(httpContext =>
                {
                    var path = httpContext.Request.Path.Value ?? "";
                    if (IsRateLimitExempt(path))
                        return RateLimitPartition.GetNoLimiter("exempt");

                    var partitionKey = ResolveRateLimitPartitionKey(httpContext);
                    return RateLimitPartition.GetFixedWindowLimiter(
                        partitionKey,
                        _ => new FixedWindowRateLimiterOptions
                        {
                            PermitLimit = globalPermit,
                            Window = TimeSpan.FromMinutes(1),
                            AutoReplenishment = true,
                            QueueLimit = 0
                        });
                });
            }
        });

        return builder;
    }

    public static WebApplicationBuilder AddScaffoldRequestTimeouts(this WebApplicationBuilder builder)
    {
        var opts = builder.Configuration.GetSection("RequestTimeout").Get<ScaffoldRequestTimeoutOptions>()
                   ?? new ScaffoldRequestTimeoutOptions();
        if (!opts.Enabled)
            return builder;

        var seconds = Math.Clamp(opts.Seconds, 5, 300);
        builder.Services.AddRequestTimeouts(options =>
        {
            options.DefaultPolicy = new RequestTimeoutPolicy
            {
                Timeout = TimeSpan.FromSeconds(seconds)
            };
        });

        return builder;
    }

    public static WebApplicationBuilder AddScaffoldOptionsValidation(this WebApplicationBuilder builder)
    {
        builder.Services.AddOptions<JwtAuthOptions>()
            .BindConfiguration("Jwt")
            .Validate(o => !string.IsNullOrWhiteSpace(o.Key) && o.Key.Length >= 32,
                "Jwt:Key must be at least 32 characters.")
            .Validate(o => !IsProductionEnvironment() || !IsKnownJwtPlaceholder(o.Key),
                "Jwt:Key must not use a template placeholder in Production. Generate a unique key (e.g. Set-PublishSettings.ps1).")
            .ValidateOnStart();

        builder.Services.AddOptions<AuthOptions>()
            .BindConfiguration("Auth")
            .Validate(o => !IsProductionEnvironment() || !IsWeakSeedAdminPassword(o.SeedAdminPassword),
                "Auth:SeedAdminPassword must be set to a strong non-placeholder value in Production.")
            .Validate(o => !IsProductionEnvironment() || !string.IsNullOrWhiteSpace(o.SeedAdminEmail),
                "Auth:SeedAdminEmail must be set in Production.")
            .ValidateOnStart();

        builder.Services.AddOptions<CorsSettings>()
            .BindConfiguration("Cors")
            .ValidateOnStart();

        builder.Services.AddOptions<RabbitMqOptions>()
            .BindConfiguration("RabbitMq")
            .Validate(o => !o.Enabled || !string.IsNullOrWhiteSpace(o.HostName),
                "RabbitMq:HostName is required when RabbitMq:Enabled=true.")
            .ValidateOnStart();

        builder.Services.AddOptions<EmailOptions>()
            .BindConfiguration("Email")
            .Validate(o => !o.Enabled
                || (!string.IsNullOrWhiteSpace(o.SmtpUsername)
                    && !string.IsNullOrWhiteSpace(o.SmtpPassword)
                    && !string.IsNullOrWhiteSpace(o.FromAddress)),
                "Email SMTP settings required when Email:Enabled=true.")
            .ValidateOnStart();

        return builder;
    }

    private static bool IsProductionEnvironment()
    {
        var env = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
                  ?? Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT")
                  ?? "";
        return string.Equals(env, "Production", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsKnownJwtPlaceholder(string? key)
    {
        if (string.IsNullOrWhiteSpace(key))
            return true;

        return key is
            "change-me-use-at-least-32-characters-long-secret"
            or "1234564646466466544464456664656664646465445";
    }

    private static bool IsWeakSeedAdminPassword(string? password)
    {
        if (string.IsNullOrWhiteSpace(password))
            return true;

        return password is "Admin123!" or "changeme";
    }

    public static Task ApplyScaffoldStartupAsync(this WebApplication app)
    {
        LogScaffoldStartupBanner(app);
        return Task.CompletedTask;
    }

    public static void UseScaffoldPipeline(this WebApplication app)
    {
        app.UseSerilogRequestLogging(options =>
        {
            options.EnrichDiagnosticContext = (diag, http) =>
            {
                diag.Set("RequestId", http.TraceIdentifier);
            };
        });

        app.UseMiddleware<RequestCorrelationMiddleware>();
        app.UseMiddleware<MaintenanceMiddleware>();

        var requestTimeout = app.Configuration.GetSection("RequestTimeout").Get<ScaffoldRequestTimeoutOptions>()
                             ?? new ScaffoldRequestTimeoutOptions();
        if (requestTimeout.Enabled)
            app.UseRequestTimeouts();

        var health = app.Configuration.GetSection("Health").Get<HealthOptions>() ?? new HealthOptions();
        if (health.Enabled)
        {
            var live = app.MapHealthChecks("/health/live", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
            {
                Predicate = check => check.Tags.Contains("live")
            });
            var ready = app.MapHealthChecks("/health/ready", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
            {
                Predicate = check => check.Tags.Contains("ready")
            });

            if (requestTimeout.Enabled)
            {
                live.DisableRequestTimeout();
                ready.DisableRequestTimeout();
            }
        }

        // UseRateLimiter is applied after UseAuthentication in Program so global
        // partitions can key by authenticated user id when present.
    }

    /// <summary>Call after UseAuthentication / UseAuthorization.</summary>
    public static void UseScaffoldRateLimiter(this WebApplication app)
    {
        app.UseRateLimiter();
    }

    private static bool IsRateLimitExempt(string path) =>
        path.StartsWith("/health", StringComparison.OrdinalIgnoreCase)
        || path.StartsWith("/swagger", StringComparison.OrdinalIgnoreCase)
        // SignalR long-polling fallback issues a request every few seconds per client; hub methods are cheap.
        || path.StartsWith("/hubs/", StringComparison.OrdinalIgnoreCase);

    private static string ResolveRateLimitPartitionKey(HttpContext httpContext)
    {
        if (httpContext.User?.Identity?.IsAuthenticated == true)
        {
            var sub = httpContext.User.FindFirst("sub")?.Value
                      ?? httpContext.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
                      ?? httpContext.User.Identity.Name;
            if (!string.IsNullOrWhiteSpace(sub))
                return $"u:{sub}";
        }

        return $"ip:{httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown"}";
    }

    private static void LogScaffoldStartupBanner(WebApplication app)
    {
        var c = app.Configuration;
        app.Logger.LogInformation(
            "Scaffold startup | Auth: pwd={Pwd} email={Email} phone={Phone} | Otp: dev={Dev} logOnly={Log} | Rabbit={Rabbit} | Redis={Redis} | Realtime={Realtime} | Email={EmailOn} | Worker delivery: email={We} sms={Ws} | Maintenance={Maint} | AutoMigrate={Migrate} | RateLimit={Rl}/{Rpm} | RequestTimeout={Rt}s | HttpResilience={Http} | Idempotency={Idem}",
            c.GetValue("Auth:EnablePasswordLogin", true),
            c.GetValue("Auth:EnableEmailAuth", true),
            c.GetValue("Auth:EnablePhoneAuth", true),
            c.GetValue("Otp:DevMode", true),
            c.GetValue("Otp:LogOnly", true),
            c.GetValue("RabbitMq:Enabled", false),
            c.GetValue("Redis:Enabled", false),
            c.GetValue("Realtime:Enabled", true) ? c.GetValue("Realtime:HubPath", "/hubs/app") : "off",
            c.GetValue("Email:Enabled", false),
            c.GetValue("Worker:EnableEmailDelivery", false),
            c.GetValue("Worker:EnableSmsOtpDelivery", false),
            c.GetValue("Maintenance:Enabled", false),
            c.GetValue("Database:AutoMigrate", false),
            c.GetValue("RateLimit:Enabled", true),
            c.GetValue("RateLimit:GlobalPerMinute", 120),
            c.GetValue("RequestTimeout:Enabled", true) ? c.GetValue("RequestTimeout:Seconds", 30) : 0,
            c.GetValue("Http:Enabled", true),
            c.GetValue("Idempotency:Enabled", false));
    }
}
