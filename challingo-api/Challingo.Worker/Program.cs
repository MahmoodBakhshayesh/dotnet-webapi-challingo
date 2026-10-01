using Challingo.Worker;
using Challingo.Worker.Jobs;
using Challingo.Worker.Scheduling;

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
