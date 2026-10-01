using Quartz;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Worker.Jobs;

/// <summary>Creates missing challenges for the coming days (idempotent).</summary>
[DisallowConcurrentExecution]
public sealed class CompetitionScheduleJob(ICompetitionScheduler scheduler, TimeProvider clock) : IJob
{
    public async ValueTask Execute(IJobExecutionContext context, CancellationToken cancellationToken) =>
        await scheduler.EnsureScheduleAsync(clock.GetUtcNow().UtcDateTime, cancellationToken);
}

/// <summary>Announces opened rounds, finalizes closed ones, closes days and weeks, pays stars (idempotent).</summary>
[DisallowConcurrentExecution]
public sealed class CompetitionCloseJob(ICompetitionCloser closer, TimeProvider clock) : IJob
{
    public async ValueTask Execute(IJobExecutionContext context, CancellationToken cancellationToken) =>
        await closer.RunAsync(clock.GetUtcNow().UtcDateTime, cancellationToken);
}
