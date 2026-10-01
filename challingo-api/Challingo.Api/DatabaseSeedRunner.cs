using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Challingo.Core.Domain.IdentityEntities;
using Challingo.Core.Settings;
using Challingo.Infrastructure.DbContexts;

namespace Challingo.Api;

public static class DatabaseSeedRunner
{
    public static async Task RunAsync(IServiceProvider services, CancellationToken cancellationToken)
    {
        await using var scope = services.CreateAsyncScope();
        var logger = scope.ServiceProvider.GetRequiredService<ILoggerFactory>()
            .CreateLogger("SeedInitialData");
        var startupHealth = scope.ServiceProvider.GetRequiredService<DatabaseStartupHealthState>();
        var databaseOptions = scope.ServiceProvider.GetRequiredService<IOptions<DatabaseOptions>>().Value;

        try
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            if (databaseOptions.AutoMigrate)
            {
                logger.LogInformation("Applying database migrations (Database:AutoMigrate=true)...");
                await db.Database.MigrateAsync(cancellationToken);
            }
            else
            {
                logger.LogInformation(
                    "Skipping database migrations (Database:AutoMigrate=false). Apply out-of-band (e.g. dotnet ef database update).");
            }

            var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<AppRole>>();
            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<AppUser>>();
            var authOptions = scope.ServiceProvider.GetRequiredService<IOptions<AuthOptions>>();

            try
            {
                await IdentitySeeders.SeedAsync(roleManager);
                await IdentitySeeders.SeedAdminUserAsync(userManager, roleManager, authOptions);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Identity seed failed — API will keep running.");
            }
        }
        catch (Exception ex)
        {
            startupHealth.MigrateFailed = true;
            startupHealth.ErrorMessage = ex.Message;
            logger.LogError(
                ex,
                "Database migrate failed — /health/ready will report degraded; fix connection string or migrations.");
        }
    }
}
