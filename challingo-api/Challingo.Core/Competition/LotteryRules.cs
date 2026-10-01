using System.Security.Cryptography;
using System.Text;

namespace Challingo.Core.Competition;

public enum LotteryPhase
{
    /// <summary>00:00–14:00 UTC: pick or change your number.</summary>
    Picking,

    /// <summary>14:00–24:00 UTC: one digit revealed every hour.</summary>
    Revealing,

    /// <summary>All ten digits out and stars paid.</summary>
    Settled,
}

/// <summary>Daily lottery timing and matching (UTC).</summary>
public static class LotteryRules
{
    public const int Digits = 10;
    public static readonly TimeSpan PickWindow = TimeSpan.FromHours(14);
    public static readonly TimeSpan RevealEvery = TimeSpan.FromHours(1);

    public static DateTime PicksCloseUtc(DateOnly day) => CompetitionCalendar.DayStartUtc(day) + PickWindow;

    /// <summary>When digit <paramref name="n"/> (1–10) is revealed: 15:00 … 24:00.</summary>
    public static DateTime RevealAtUtc(DateOnly day, int n) => PicksCloseUtc(day) + RevealEvery * n;

    /// <summary>How many digits are public at <paramref name="nowUtc"/>.</summary>
    public static int RevealedCount(DateOnly day, DateTime nowUtc) =>
        nowUtc < PicksCloseUtc(day) ? 0 : Math.Clamp((int)((nowUtc - PicksCloseUtc(day)) / RevealEvery), 0, Digits);

    /// <summary>Matching digits counted from the first: 1234… vs 1299… = 2.</summary>
    public static int MatchLength(string pick, string number)
    {
        var n = 0;
        while (n < Math.Min(pick.Length, number.Length) && pick[n] == number[n])
            n++;
        return n;
    }

    public static bool IsValidNumber(string? value) => value is { Length: Digits } && value.All(char.IsAsciiDigit);

    public static string RandomNumber() =>
        string.Create(Digits, 0, (span, _) =>
        {
            for (var i = 0; i < span.Length; i++)
                span[i] = (char)('0' + RandomNumberGenerator.GetInt32(10));
        });

    /// <summary>SHA-256 of "salt:number", lowercase hex: published before picks open.</summary>
    public static string Commit(string salt, string number) =>
        Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes($"{salt}:{number}")));
}
