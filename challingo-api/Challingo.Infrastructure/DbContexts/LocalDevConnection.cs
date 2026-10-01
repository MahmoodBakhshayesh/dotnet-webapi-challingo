using System.Text.Json;

namespace Challingo.Infrastructure.DbContexts;

internal static class LocalDevConnection
{
    private const string EnvKey = "ConnectionStrings__Database";
    private const string DefaultConnection =
        "Host=127.0.0.1;Port=5434;Database=challingo;Username=scaffoldadmin;Password=changeme;Pooling=true";

    public static string Resolve()
    {
        var fromEnv = Environment.GetEnvironmentVariable(EnvKey);
        if (!string.IsNullOrWhiteSpace(fromEnv))
        {
            return fromEnv;
        }

        foreach (var root in FindSearchRoots())
        {
            var envPath = Path.Combine(root, ".env");
            if (File.Exists(envPath))
            {
                LoadDotEnv(envPath);
                fromEnv = Environment.GetEnvironmentVariable(EnvKey);
                if (!string.IsNullOrWhiteSpace(fromEnv))
                {
                    return fromEnv;
                }
            }

            var apiDir = Directory.GetDirectories(root, "*Api", SearchOption.TopDirectoryOnly).FirstOrDefault();
            if (apiDir is not null)
            {
                var fromJson = ReadAppSettingsConnection(apiDir);
                if (!string.IsNullOrWhiteSpace(fromJson))
                {
                    return fromJson;
                }
            }
        }

        return DefaultConnection;
    }

    private static IEnumerable<string> FindSearchRoots()
    {
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var start in new[] { Directory.GetCurrentDirectory(), AppContext.BaseDirectory })
        {
            var dir = new DirectoryInfo(start);
            while (dir is not null)
            {
                if (seen.Add(dir.FullName))
                {
                    yield return dir.FullName;
                }

                dir = dir.Parent;
            }
        }
    }

    private static void LoadDotEnv(string path)
    {
        foreach (var rawLine in File.ReadAllLines(path))
        {
            var line = rawLine.Trim();
            if (line.Length == 0 || line.StartsWith('#'))
            {
                continue;
            }

            var eq = line.IndexOf('=');
            if (eq <= 0)
            {
                continue;
            }

            var key = line[..eq].Trim();
            var value = line[(eq + 1)..].Trim().Trim('"');
            Environment.SetEnvironmentVariable(key, value);
        }
    }

    private static string? ReadAppSettingsConnection(string apiProjectDir)
    {
        var path = Path.Combine(apiProjectDir, "appsettings.json");
        if (!File.Exists(path))
        {
            return null;
        }

        using var doc = JsonDocument.Parse(File.ReadAllText(path));
        if (!doc.RootElement.TryGetProperty("ConnectionStrings", out var connectionStrings))
        {
            return null;
        }

        if (connectionStrings.TryGetProperty("Database", out var database))
        {
            return database.GetString();
        }

        return null;
    }
}
