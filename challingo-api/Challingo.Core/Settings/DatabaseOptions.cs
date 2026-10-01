namespace Challingo.Core.Settings;

public sealed class DatabaseOptions
{
    /// <summary>
    /// Apply EF migrations on API startup (env: Database__AutoMigrate).
    /// Keep a single API replica while this is true — concurrent MigrateAsync from multiple
    /// replicas is unsafe. For multi-replica, set false and run migrations out-of-band.
    /// </summary>
    public bool AutoMigrate { get; set; }
}
