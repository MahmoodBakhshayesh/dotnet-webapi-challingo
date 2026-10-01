using Challingo.Core.Domain.Enums;

namespace Challingo.Core.Competition;

/// <summary>One attempt as scoring sees it.</summary>
public sealed record ScoredAttempt(Guid AttemptId, Guid UserId, AttemptStatus Status, long? ElapsedMs, string? ResultJson, double? RankScore, string? CountryCode);

public sealed record AttemptPoints(Guid AttemptId, Guid UserId, int Rank, int Points, double? RankScore, string? CountryCode);

/// <summary>
/// 0–1000 points per challenge. From <see cref="Settings.CompetitionOptions.SmallRoundThreshold"/> players:
/// percentile <c>round(1000·(N−r)/(N−1))</c>, ties share a rank. Smaller rounds score against par so a
/// three-player round does not hand out 0 and 1000. Unfinished attempts score 0 either way.
/// </summary>
public static class PointsCalculator
{
    public static IReadOnlyList<AttemptPoints> Assign(string gameKey, IReadOnlyList<ScoredAttempt> attempts, int smallRoundThreshold)
    {
        var ordered = attempts.OrderByDescending(a => a.RankScore ?? double.MinValue).ToList();
        var n = ordered.Count;
        var result = new List<AttemptPoints>(n);
        var rank = 0;
        var previousPoints = 1000;
        for (var i = 0; i < n; i++)
        {
            var a = ordered[i];
            var tied = i > 0 && Equals(ordered[i - 1].RankScore, a.RankScore);
            if (!tied)
                rank = i + 1;

            int points;
            if (a.RankScore is null)
                points = 0;
            else if (tied)
                points = result[i - 1].Points;
            else if (n >= smallRoundThreshold)
                points = Percentile(rank, n);
            else
                points = Math.Min(previousPoints, ParPoints(gameKey, a.Status, a.ElapsedMs, a.ResultJson));

            if (a.RankScore is not null)
                previousPoints = points;
            result.Add(new AttemptPoints(a.AttemptId, a.UserId, rank, points, a.RankScore, a.CountryCode));
        }
        return result;
    }

    public static int Percentile(long rank, long n) =>
        n <= 1 ? 1000 : (int)Math.Round(1000.0 * (n - rank) / (n - 1), MidpointRounding.AwayFromZero);

    /// <summary>Seconds a good player needs; tuned with real data later.</summary>
    public static int ParSeconds(string gameKey) => gameKey switch
    {
        "path-link" => 150,
        "mine-logic" or "code-breaker" or "word-guess" => 180,
        "kakuro" => 300,
        _ => 240,
    };

    /// <summary>Word points that count as a full score in Word Hunt.</summary>
    public const int WordHuntParPoints = 30;

    /// <summary>Points from the attempt alone (no other players needed): small rounds and the live Grand board.</summary>
    public static int ParPoints(string gameKey, AttemptStatus status, long? elapsedMs, string? resultJson)
    {
        if (status == AttemptStatus.Failed)
            return 100;
        if (status != AttemptStatus.Solved)
            return 0;

        var result = RankScore.Read(resultJson);
        if (gameKey == "word-hunt")
            return (int)Math.Min(1000, Math.Round(1000.0 * RankScore.Int(result, "points") / WordHuntParPoints));

        // Smooth curve, so close finishes rarely tie: instant = 1, par = 2/3, 2× par = 1/2, floor 0.2.
        var seconds = Math.Max(0, (elapsedMs ?? 100_000_000) / 1000.0);
        var speed = Math.Max(0.2, 1 / (1 + seconds / (2.0 * ParSeconds(gameKey))));
        double quality = gameKey switch
        {
            "code-breaker" or "word-guess" => Math.Max(0.4, 1 - 0.08 * (RankScore.Int(result, "guesses") - 1)),
            "number-merge" => Math.Clamp(ParMoves(RankScore.Int(result, "maxTile")) / (double)Math.Max(1, RankScore.Int(result, "moves")), 0.3, 1.0),
            _ => 1.0,
        };
        // Guess and move games rank by quality first, so quality weighs more there.
        var score = gameKey is "code-breaker" or "word-guess" or "number-merge"
            ? quality * (0.8 + 0.2 * speed)
            : speed;
        return (int)Math.Round(1000 * score, MidpointRounding.AwayFromZero);
    }

    private static long ParMoves(long target) => Math.Max(20, target / 2);
}
