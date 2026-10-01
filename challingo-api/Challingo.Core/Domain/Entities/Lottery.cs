namespace Challingo.Core.Domain.Entities;

/// <summary>
/// The daily lottery (UTC): picks are open 00:00–14:00, then one digit of <see cref="Number"/> is revealed every hour
/// (15:00 … 24:00). The longest match from the first digit wins and splits the pot; no match rolls the pot over.
/// <see cref="CommitHash"/> = SHA-256("{Salt}:{Number}") is public from the start, so the number cannot change later.
/// </summary>
public class LotteryDraw : BaseEntity
{
    /// <summary>UTC date, e.g. <c>2026-10-05</c>.</summary>
    public string DayKey { get; set; } = "";

    /// <summary>Ten digits; secret until revealed digit by digit.</summary>
    public string Number { get; set; } = "";

    /// <summary>Random hex; published with the result so anyone can check <see cref="CommitHash"/>.</summary>
    public string Salt { get; set; } = "";

    public string CommitHash { get; set; } = "";

    /// <summary>Stars to share: the daily prize plus any rollover.</summary>
    public int Pot { get; set; }

    /// <summary>Digits already announced to clients (0–10).</summary>
    public int AnnouncedDigits { get; set; }

    public DateTime? SettledAtUtc { get; set; }

    /// <summary>Set on settle: winning match length (0 = nobody matched the first digit) and winners.</summary>
    public int? WinningMatch { get; set; }
    public int? WinnerCount { get; set; }
    public int? PrizePerWinner { get; set; }
}

/// <summary>A player's pick for one draw (one per player per day; can be changed until picks close).</summary>
public class LotteryTicket
{
    public Guid DrawId { get; set; }
    public Guid UserId { get; set; }

    /// <summary>Ten digits.</summary>
    public string Number { get; set; } = "";

    public DateTime PickedAtUtc { get; set; }
}
