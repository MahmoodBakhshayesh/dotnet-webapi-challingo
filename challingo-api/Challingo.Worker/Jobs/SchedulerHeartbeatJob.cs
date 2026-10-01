using Microsoft.Extensions.Logging;
using Quartz;

namespace Challingo.Worker.Jobs;

/// <summary>
/// Example Quartz job (off by default: Scheduler__Jobs__Heartbeat__Enabled=true). Copy this shape for real jobs:
/// [DisallowConcurrentExecution], constructor-injected services (scoped per run), honour the cancellation token.
/// Push to app clients with IRealtimeNotifier; update boards with ILeaderboardStore.
/// </summary>
[DisallowConcurrentExecution]
public sealed class SchedulerHeartbeatJob(ILogger<SchedulerHeartbeatJob> logger) : IJob
{
    public ValueTask Execute(IJobExecutionContext context, CancellationToken cancellationToken)
    {
        logger.LogInformation(
            "Scheduler heartbeat {FireTime:u} (scheduled {ScheduledTime:u}, next {NextTime:u})",
            context.FireTimeUtc,
            context.ScheduledFireTimeUtc,
            context.NextFireTimeUtc);
        return ValueTask.CompletedTask;
    }
}
