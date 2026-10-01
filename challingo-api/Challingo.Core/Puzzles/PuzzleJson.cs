using System.Text.Json;

namespace Challingo.Core.Puzzles;

/// <summary>Shared camelCase JSON for puzzle payloads (the app reads the same shapes).</summary>
public static class PuzzleJson
{
    public static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);

    public static string Write<T>(T value) => JsonSerializer.Serialize(value, Options);

    public static T Read<T>(string json) => JsonSerializer.Deserialize<T>(json, Options)!;

    /// <summary>Parses app input; null when it is not valid JSON of that shape.</summary>
    public static T? TryRead<T>(string json) where T : class
    {
        try
        {
            return JsonSerializer.Deserialize<T>(json, Options);
        }
        catch (JsonException)
        {
            return null;
        }
    }

    /// <summary>In-place Fisher–Yates shuffle driven by <paramref name="rng"/> (deterministic per seed).</summary>
    public static void Shuffle<T>(this Random rng, IList<T> items)
    {
        for (var i = items.Count - 1; i > 0; i--)
        {
            var j = rng.Next(i + 1);
            (items[i], items[j]) = (items[j], items[i]);
        }
    }
}
