using System.Globalization;

namespace Challingo.Core.Competition;

/// <summary>
/// UTC timetable. Every game repeats on its own timer (see <see cref="RunTimetable"/>); runs line up with midnight UTC.
/// Sunday additionally has the Grand Challenge, open the whole UTC day.
/// </summary>
public static class CompetitionCalendar
{
    public static DateOnly UtcDate(DateTime utc) => DateOnly.FromDateTime(utc);

    public static string DayKey(DateOnly date) => date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    public static string MonthKey(DateOnly date) => date.ToString("yyyy-MM", CultureInfo.InvariantCulture);

    public static string WeekKey(DateOnly date) =>
        $"{ISOWeek.GetYear(date.ToDateTime(TimeOnly.MinValue))}-W{ISOWeek.GetWeekOfYear(date.ToDateTime(TimeOnly.MinValue)):00}";

    public static bool IsGrandDay(DateOnly date) => date.DayOfWeek == DayOfWeek.Sunday;

    /// <summary>Monday of the ISO week that contains <paramref name="date"/>.</summary>
    public static DateOnly WeekStart(DateOnly date) => date.AddDays(-(((int)date.DayOfWeek + 6) % 7));

    public static DateTime DayStartUtc(DateOnly date) => date.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);

    /// <summary>Sunday of the week that contains <paramref name="date"/>.</summary>
    public static DateOnly WeekSunday(DateOnly date) => WeekStart(date).AddDays(6);

    /// <summary>Start of the run of a game that contains <paramref name="utc"/>.</summary>
    public static DateTime RunStart(DateTime utc, TimeSpan every)
    {
        var dayStart = DayStartUtc(UtcDate(utc));
        return dayStart + every * Math.Floor((utc - dayStart) / every);
    }

    /// <summary>Run number within the UTC day (1 = the run starting at 00:00).</summary>
    public static int RunNumber(DateTime runStart, TimeSpan every) =>
        (int)((runStart - DayStartUtc(UtcDate(runStart))) / every) + 1;

    public static string RunSlot(string gameKey, DateTime runStart) =>
        $"run:{gameKey}:{runStart.ToString("yyyy-MM-dd'T'HHmm", CultureInfo.InvariantCulture)}";

    public static (DateTime Opens, DateTime Closes) GrandWindow(DateOnly sunday) =>
        (DayStartUtc(sunday), DayStartUtc(sunday).AddDays(1));

    public static string GrandSlot(DateOnly sunday, int sequence) => $"grand:{DayKey(sunday)}:{sequence}";
}
