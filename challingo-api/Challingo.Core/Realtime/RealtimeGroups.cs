namespace Challingo.Core.Realtime;

public static class RealtimeGroups
{
    /// <summary>Every connection of a user joins this group automatically.</summary>
    public static string User(string userId) => $"user:{userId}";
}
