using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Infrastructure.Storage;

public sealed class LocalFileStorage(
    IOptions<StorageOptions> options,
    ILogger<LocalFileStorage> logger) : IFileStorage
{
    public async Task<string> SaveAsync(string relativePath, Stream content, CancellationToken ct = default)
    {
        var path = ResolvePath(relativePath);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        await using var file = File.Create(path);
        await content.CopyToAsync(file, ct);
        logger.LogDebug("Saved file {Path}", relativePath);
        return relativePath.Replace('\\', '/');
    }

    public Task<Stream?> OpenReadAsync(string relativePath, CancellationToken ct = default)
    {
        var path = ResolvePath(relativePath);
        if (!File.Exists(path))
            return Task.FromResult<Stream?>(null);
        return Task.FromResult<Stream?>((Stream)File.OpenRead(path));
    }

    public string GetPublicUrl(string relativePath) =>
        "/" + relativePath.TrimStart('/').Replace('\\', '/');

    private string ResolvePath(string relativePath)
    {
        var root = Path.GetFullPath(options.Value.LocalRoot);
        var combined = Path.GetFullPath(Path.Combine(root, relativePath));
        if (!combined.StartsWith(root, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Invalid storage path.");
        return combined;
    }
}
