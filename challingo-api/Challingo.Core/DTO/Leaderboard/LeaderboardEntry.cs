namespace Challingo.Core.DTO.Leaderboard;

/// <param name="Rank">1-based rank (1 = highest score).</param>
public sealed record LeaderboardEntry(string MemberId, double Score, long Rank);
