namespace Challingo.Core.Domain.Entities;

/// <summary>Marks a day or week as closed and paid out (key: <c>day:2026-10-05</c>, <c>week:2026-W41</c>).</summary>
public class PeriodClose
{
    public string Key { get; set; } = "";
    public DateTime ClosedAtUtc { get; set; }
}
