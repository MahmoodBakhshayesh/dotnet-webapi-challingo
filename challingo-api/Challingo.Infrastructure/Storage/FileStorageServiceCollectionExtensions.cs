using Microsoft.Extensions.DependencyInjection;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Infrastructure.Storage;

public static class FileStorageServiceCollectionExtensions
{
    public static IServiceCollection AddScaffoldFileStorage(this IServiceCollection services)
    {
        services.AddSingleton<IFileStorage, LocalFileStorage>();
        return services;
    }
}
