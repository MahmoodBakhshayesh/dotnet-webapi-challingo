using Challingo.Worker;
using Challingo.Worker.Jobs;
using Challingo.Worker.Scheduling;

// English only, and the same dates and numbers on every machine (a host locale such as en_IR would switch calendars).
System.Globalization.CultureInfo.DefaultThreadCurrentCulture = System.Globalization.CultureInfo.InvariantCulture;
System.Globalization.CultureInfo.DefaultThreadCurrentUICulture = System.Globalization.CultureInfo.InvariantCulture;
System.Globalization.CultureInfo.CurrentCulture = System.Globalization.CultureInfo.InvariantCulture;
System.Globalization.CultureInfo.CurrentUICulture = System.Globalization.CultureInfo.InvariantCulture;

try
{
    foreach (var path in FindEnvFilePaths())
    {
        if (File.Exists(path))
        {
            DotNetEnv.Env.Load(path);
            break;
        }
    }

    var builder = Host.CreateApplicationBuilder(args);
    builder.AddWorkerServices();
    builder.AddWorkerScheduler((q, scheduler) =>
    {
        q.AddScaffoldJob<SchedulerHeartbeatJob>(scheduler, "Heartbeat", "0 0/5 * * * ?", enabledByDefault: false);
        // Competition: plan ahead every 15 minutes; close rounds a few seconds after each minute.
        q.AddScaffoldJob<CompetitionScheduleJob>(scheduler, "CompetitionSchedule", "0 1/15 * * * ?");
        q.AddScaffoldJob<CompetitionCloseJob>(scheduler, "CompetitionClose", "5 * * * * ?");
    });

    builder.Services.AddHostedService<WorkerDatabaseWarmupJob>();
    builder.Services.AddHostedService<WorkerIdleJob>();
    builder.Services.AddHostedService<EmailDeliveryBackgroundService>();
    builder.Services.AddHostedService<SmsOtpDeliveryBackgroundService>();

    var enableSample = builder.Configuration.GetValue("Worker:EnableSampleJob", false);
    if (enableSample)
    {
        builder.Services.AddHostedService<SampleBackgroundJob>();
    }

    var host = builder.Build();
    await host.RunAsync();
}
catch (Exception ex)
{
    Console.Error.WriteLine($"FATAL: worker failed to start: {ex}");
    Environment.Exit(1);
}

static IEnumerable<string> FindEnvFilePaths()
{
    var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    foreach (var start in new[] { Directory.GetCurrentDirectory(), AppContext.BaseDirectory })
    {
        var dir = new DirectoryInfo(start);
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, ".env");
            if (seen.Add(candidate))
            {
                yield return candidate;
            }

            dir = dir.Parent;
        }
    }
}
