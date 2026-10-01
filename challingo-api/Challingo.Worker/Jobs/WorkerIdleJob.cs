using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Challingo.Worker.Jobs;

/// <summary>
/// Keeps the worker process running when no custom jobs are registered. Logs a heartbeat only.
/// </summary>
public sealed class WorkerIdleJob : BackgroundService
{
    private readonly ILogger<WorkerIdleJob> _logger;
    private readonly IConfiguration _configuration;

    public WorkerIdleJob(ILogger<WorkerIdleJob> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var interval = _configuration.GetValue("Worker:PollIntervalSeconds", 300);
        _logger.LogInformation(
            "Challingo worker idle (no custom jobs). Heartbeat every {Interval}s.",
            interval);

        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(TimeSpan.FromSeconds(interval), stoppingToken);
            _logger.LogInformation("Worker idle heartbeat at {Time}", DateTimeOffset.UtcNow);
        }
    }
}
