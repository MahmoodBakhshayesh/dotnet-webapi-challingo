namespace Challingo.Core.Domain.Entities;

/// <summary>Game-facing profile, 1:1 with <see cref="IdentityEntities.AppUser"/>.</summary>
public class PlayerProfile : BaseEntity
{
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = "";
    public bool IsGuest { get; set; }

    /// <summary>IANA zone id (e.g. <c>Europe/Berlin</c>). Decides the player's local date for the daily puzzle.</summary>
    public string TimeZoneId { get; set; } = "Etc/UTC";

    /// <summary>ISO 3166-1 alpha-2, derived from <see cref="TimeZoneId"/>; null for zones without a country (UTC).</summary>
    public string? CountryCode { get; set; }

    /// <summary>When the player last changed their zone themselves; the first set after sign-up does not count.</summary>
    public DateTime? TimeZoneChangedAtUtc { get; set; }

    /// <summary>The zone in force before the last change; still used until the next local midnight.</summary>
    public string? PreviousTimeZoneId { get; set; }
}
