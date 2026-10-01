namespace Challingo.Core.DTO.Players;

public sealed class MeResponse
{
    public Guid UserId { get; init; }
    public required string DisplayName { get; init; }
    public bool IsGuest { get; init; }
    public string? Email { get; init; }
    public required string TimeZoneId { get; init; }
    public string? CountryCode { get; init; }

    /// <summary>The player's current local date (server-computed; the app must not use the device clock).</summary>
    public DateOnly LocalDate { get; init; }

    /// <summary>Null when the zone can be changed now.</summary>
    public DateTime? NextTimeZoneChangeAtUtc { get; init; }
}

public sealed class UpdateMeRequest
{
    public string DisplayName { get; set; } = "";
}

public sealed class SetTimeZoneRequest
{
    public string TimeZoneId { get; set; } = "";
}

public sealed class CreateGuestRequest
{
    /// <summary>The device's IANA zone; optional, defaults to UTC.</summary>
    public string? TimeZoneId { get; set; }
}
