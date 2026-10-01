using Challingo.Core.Domain.Enums;
using Newtonsoft.Json.Linq;

namespace Challingo.Core.Competition;

/// <summary>
/// One sortable number per finished attempt (higher is better), so boards are plain sorted sets:
/// solved beats failed; then the game's own measure (word points, fewest guesses, fewest moves…); then time.
/// Layout: tier × 10^15 + measure × 10^8 + (10^8 − ms), exact in a double.
/// </summary>
public static class RankScore
{
    private const double TierUnit = 1e15;
    private const double MeasureUnit = 1e8;
    private const long MaxMs = 99_999_999;
    private const long MaxMeasure = 9_999_999;

    public static double? Compute(string gameKey, AttemptStatus status, long? elapsedMs, string? resultJson)
    {
        var tier = status switch
        {
            AttemptStatus.Solved => 2,
            AttemptStatus.Failed => 1,
            _ => 0,
        };
        if (tier == 0)
            return null;

        var measure = Math.Clamp(Measure(gameKey, status, Read(resultJson)), 0, MaxMeasure);
        var ms = Math.Clamp(elapsedMs ?? MaxMs, 0, MaxMs);
        return tier * TierUnit + measure * MeasureUnit + (MaxMs + 1 - ms);
    }

    private static long Measure(string gameKey, AttemptStatus status, JObject result) => gameKey switch
    {
        "word-hunt" => Int(result, "points"),
        "code-breaker" or "word-guess" => status == AttemptStatus.Solved ? 1000 - Int(result, "guesses") : 0,
        "number-merge" => status == AttemptStatus.Solved ? 1_000_000 - Int(result, "moves") : 0,
        "mine-logic" => status == AttemptStatus.Failed ? Int(result, "revealed") : 0,
        _ => 0,
    };

    internal static long Int(JObject result, string name) => result.Value<long?>(name) ?? 0;

    internal static JObject Read(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
            return [];
        try
        {
            return JToken.Parse(json) as JObject ?? [];
        }
        catch (Newtonsoft.Json.JsonException)
        {
            return [];
        }
    }
}
