using System.Globalization;

namespace Challingo.Core.Competition;

/// <summary>
/// Fixed UTC timetable. Mon–Sat: six ranked rounds (00, 04, 08, 12, 16, 20 UTC) and a daily puzzle per local date.
/// Sunday: the Grand Challenge only, open the whole UTC day.
/// </summary>
public static class CompetitionCalendar
{
    public const int RoundsPerDay = 6;
    public const int GrandGames = 6;
    public static readonly TimeSpan RoundLength = TimeSpan.FromHours(4);

    /// <summary>Earliest and latest UTC offsets in use (Kiribati, Baker Island): bounds of a local date.</summary>
    private static readonly TimeSpan EarliestOffset = TimeSpan.FromHours(14);
    private static readonly TimeSpan LatestOffset = TimeSpan.FromHours(12);

    public static DateOnly UtcDate(DateTime utc) => DateOnly.FromDateTime(utc);

    public static string DayKey(DateOnly date) => date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    public static string WeekKey(DateOnly date) =>
        $"{ISOWeek.GetYear(date.ToDateTime(TimeOnly.MinValue))}-W{ISOWeek.GetWeekOfYear(date.ToDateTime(TimeOnly.MinValue)):00}";

    public static bool IsGrandDay(DateOnly date) => date.DayOfWeek == DayOfWeek.Sunday;

    /// <summary>Monday of the ISO week that contains <paramref name="date"/>.</summary>
    public static DateOnly WeekStart(DateOnly date) => date.AddDays(-(((int)date.DayOfWeek + 6) % 7));

    public static DateTime DayStartUtc(DateOnly date) => date.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);

    /// <summary>Round <paramref name="sequence"/> (1–6) of a UTC date.</summary>
    public static (DateTime Opens, DateTime Closes) RoundWindow(DateOnly date, int sequence)
    {
        var opens = DayStartUtc(date) + RoundLength * (sequence - 1);
        return (opens, opens + RoundLength);
    }

    /// <summary>The round open at <paramref name="utc"/> (null on Sunday).</summary>
    public static int? RoundAt(DateTime utc) =>
        IsGrandDay(UtcDate(utc)) ? null : (int)((utc - DayStartUtc(UtcDate(utc))) / RoundLength) + 1;

    /// <summary>A daily puzzle for local date D can be played from D's first midnight on Earth to its last.</summary>
    public static (DateTime Opens, DateTime Closes) DailyWindow(DateOnly localDate) =>
        (DayStartUtc(localDate) - EarliestOffset, DayStartUtc(localDate).AddDays(1) + LatestOffset);

    public static (DateTime Opens, DateTime Closes) GrandWindow(DateOnly sunday) =>
        (DayStartUtc(sunday), DayStartUtc(sunday).AddDays(1));

    public static string RankedSlot(DateOnly date, int sequence) => $"ranked:{DayKey(date)}:{sequence}";
    public static string DailySlot(DateOnly localDate) => $"daily:{DayKey(localDate)}";
    public static string GrandSlot(DateOnly sunday, int sequence) => $"grand:{DayKey(sunday)}:{sequence}";
}
