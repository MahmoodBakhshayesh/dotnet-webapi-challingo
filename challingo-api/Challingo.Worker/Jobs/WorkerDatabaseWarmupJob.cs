using Challingo.Infrastructure.DbContexts;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Challingo.Worker.Jobs;

/// <summary>
/// Waits for Postgres schema (not just connectivity) before other jobs run —
/// avoids racing API AutoMigrate on first boot.
/// </summary>
public sealed class WorkerDatabaseWarmupJob : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<WorkerDatabaseWarmupJob> _logger;

    public WorkerDatabaseWarmupJob(
        IServiceScopeFactory scopeFactory,
        ILogger<WorkerDatabaseWarmupJob> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var attempt = 0;
        while (!stoppingToken.IsCancellationRequested)
        {
            attempt++;
            try
            {
                await using var scope = _scopeFactory.CreateAsyncScope();
                var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                if (await db.Database.CanConnectAsync(stoppingToken)
                    && await SchemaReadyAsync(db, stoppingToken))
                {
                    _logger.LogInformation("Worker database schema ready (attempt {Attempt}).", attempt);
                    return;
                }

                _logger.LogWarning(
                    "Worker database connected but schema not ready yet (attempt {Attempt}).",
                    attempt);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(
                    ex,
                    "Worker database not ready (attempt {Attempt}); retrying in 15s.",
                    attempt);
            }

            await Task.Delay(TimeSpan.FromSeconds(15), stoppingToken);
        }
    }

    private static async Task<bool> SchemaReadyAsync(AppDbContext db, CancellationToken cancellationToken)
    {
        // Prefer Identity table; fall back to EF migrations history for empty-but-migrated DBs.
        try
        {
            await db.Database.ExecuteSqlRawAsync(
                """SELECT 1 FROM "AspNetUsers" LIMIT 1""",
                cancellationToken);
            return true;
        }
        catch
        {
            // table missing or not yet migrated
        }

        try
        {
            await db.Database.ExecuteSqlRawAsync(
                """SELECT 1 FROM "__EFMigrationsHistory" LIMIT 1""",
                cancellationToken);
            return true;
        }
        catch
        {
            return false;
        }
    }
}
