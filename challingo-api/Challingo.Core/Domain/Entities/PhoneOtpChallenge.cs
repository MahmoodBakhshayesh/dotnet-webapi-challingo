using Challingo.Core.Domain.Enums;
using Challingo.Core.Domain.IdentityEntities;

namespace Challingo.Core.Domain.Entities;

public class PhoneOtpChallenge
{
    public Guid Id { get; set; }
    public DateTime CreatedAt { get; set; }
    /// <summary>Phone number or prefixed key such as email:user@example.com</summary>
    public required string PhoneNumber { get; set; }
    public required string CodeHash { get; set; }
    public DateTime ExpiresAtUtc { get; set; }
    public OtpChallengeStatus Status { get; set; } = OtpChallengeStatus.Pending;
    public int AttemptCount { get; set; }
    public Guid? UserId { get; set; }
    public DateTime? VerifiedAtUtc { get; set; }
    public AppUser? User { get; set; }
}
