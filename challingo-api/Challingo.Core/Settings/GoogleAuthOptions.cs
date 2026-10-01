namespace Challingo.Core.Settings;

public sealed class GoogleAuthOptions
{
    /// <summary>
    /// OAuth client ID(s) used to validate Google ID tokens from the app.
    /// Comma-separated: Web client ID (required) plus optional Android/iOS client IDs.
    /// </summary>
    public string? ClientId { get; set; }

    public string[] GetAudienceClientIds()
    {
        if (string.IsNullOrWhiteSpace(ClientId))
            return [];

        return ClientId
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(NormalizeClientId)
            .Where(id => id.Length > 0)
            .Distinct(StringComparer.Ordinal)
            .ToArray();
    }

    /// <summary>Normalize env / .env quoting and whitespace for a comma-separated client ID list.</summary>
    public static string? NormalizeClientIdList(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
            return null;

        var ids = raw
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(NormalizeClientId)
            .Where(id => id.Length > 0)
            .Distinct(StringComparer.Ordinal)
            .ToArray();

        return ids.Length == 0 ? null : string.Join(',', ids);
    }

    private static string NormalizeClientId(string id)
    {
        id = id.Trim();
        if (id.Length >= 2 && id[0] == '"' && id[^1] == '"')
            id = id[1..^1].Trim();
        if (id.Length >= 2 && id[0] == '\'' && id[^1] == '\'')
            id = id[1..^1].Trim();
        return id;
    }
}
