using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Challingo.Worker.Jobs;

/// <summary>
/// Optional dev-only verbose heartbeat. Production uses WorkerIdleJob instead.
/// </summary>
public sealed class SampleBackgroundJob : BackgroundService
{
    private readonly ILogger<SampleBackgroundJob> _logger;
    private readonly IConfiguration _configuration;

    public SampleBackgroundJob(ILogger<SampleBackgroundJob> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var interval = _configuration.GetValue("Worker:PollIntervalSeconds", 60);
        _logger.LogInformation("Challingo worker started. Poll interval: {Interval}s", interval);

        while (!stoppingToken.IsCancellationRequested)
        {
            _logger.LogInformation("Worker heartbeat at {Time}", DateTimeOffset.UtcNow);
            // TODO: process outbox, emails, Stripe webhooks, reports, etc.
            await Task.Delay(TimeSpan.FromSeconds(interval), stoppingToken);
        }
    }
}
