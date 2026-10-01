using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Challingo.Core.Settings;
using Quartz;

namespace Challingo.Worker.Scheduling;

public static class SchedulerExtensions
{
    /// <summary>
    /// Quartz cron scheduler (Scheduler__Enabled). Register jobs in <paramref name="configureJobs"/> with
    /// <see cref="AddScaffoldJob{TJob}"/>; each job's Enabled/Cron can be overridden from env.
    /// </summary>
    public static HostApplicationBuilder AddWorkerScheduler(
        this HostApplicationBuilder builder,
        Action<IQuartzBuilder, SchedulerOptions> configureJobs)
    {
        builder.Services.AddOptions<SchedulerOptions>().BindConfiguration("Scheduler");
        var options = builder.Configuration.GetSection("Scheduler").Get<SchedulerOptions>() ?? new SchedulerOptions();
        if (!options.Enabled)
            return builder;

        builder.Services.AddQuartz(q =>
        {
            // In-memory store: one Worker replica. Jobs must be idempotent and catch up after downtime.
            q.UseInMemoryStore();
            q.UseDefaultThreadPool(pool => pool.MaxConcurrency = 4);
            configureJobs(q, options);
        });
        builder.Services.AddQuartzHostedService(o => o.WaitForJobsToComplete = true);
        return builder;
    }

    /// <summary>
    /// Adds a cron-triggered job (UTC). Env overrides: <c>Scheduler__Jobs__{name}__Enabled</c>, <c>Scheduler__Jobs__{name}__Cron</c>.
    /// Quartz cron has a seconds field: <c>0 0 * * * ?</c> = hourly, <c>0 0/15 * * * ?</c> = every 15 minutes.
    /// </summary>
    public static IQuartzBuilder AddScaffoldJob<TJob>(
        this IQuartzBuilder q,
        SchedulerOptions options,
        string name,
        string defaultCron,
        bool enabledByDefault = true)
        where TJob : class, IJob
    {
        options.Jobs.TryGetValue(name, out var jobOptions);
        if (!(jobOptions?.Enabled ?? enabledByDefault))
            return q;

        var cron = string.IsNullOrWhiteSpace(jobOptions?.Cron) ? defaultCron : jobOptions!.Cron!;
        try
        {
            _ = new CronExpression(cron);
        }
        catch (FormatException ex)
        {
            throw new InvalidOperationException($"Scheduler:Jobs:{name}:Cron '{cron}' is not a valid Quartz cron expression.", ex);
        }

        var jobKey = new JobKey(name);
        q.AddJob<TJob>(job => job.WithIdentity(jobKey));
        q.AddTrigger(trigger => trigger
            .ForJob(jobKey)
            .WithIdentity($"{name}-cron")
            .WithSchedule(CronScheduleBuilder.Create(cron)
                .InTimeZone(TimeZoneInfo.Utc)
                // Fire once on recovery instead of replaying every missed slot.
                .WithMisfireInstruction(CronTriggerMisfireInstruction.FireAndProceed)));
        return q;
    }
}
