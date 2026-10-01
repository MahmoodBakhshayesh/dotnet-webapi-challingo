namespace Challingo.Core.ServiceInterfaces;

public interface IFileStorage
{
    Task<string> SaveAsync(string relativePath, Stream content, CancellationToken ct = default);
    Task<Stream?> OpenReadAsync(string relativePath, CancellationToken ct = default);
    string GetPublicUrl(string relativePath);
}
