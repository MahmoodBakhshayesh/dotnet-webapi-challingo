namespace Challingo.Api.Extensions;

using Challingo.Api;

public static class IdentityExtensions
{
    public static Task SeedInitialDataAsync(this WebApplication app) =>
        DatabaseSeedRunner.RunAsync(app.Services, CancellationToken.None);
}
