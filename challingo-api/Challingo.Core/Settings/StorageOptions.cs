namespace Challingo.Core.Settings;

public sealed class StorageOptions
{
    /// <summary>Local | (future: S3)</summary>
    public string Provider { get; set; } = "Local";
    public string LocalRoot { get; set; } = "wwwroot/uploads";
}
