using Challingo.Core.Domain.Entities;

namespace Challingo.Core.Domain.RepositoryInterfaces;

public interface IPhoneOtpRepository
{
    Task AddAsync(PhoneOtpChallenge challenge, CancellationToken ct = default);
    Task<PhoneOtpChallenge?> GetLatestPendingAsync(string channelKey, CancellationToken ct = default);
    Task<PhoneOtpChallenge?> FindValidAsync(string channelKey, string code, CancellationToken ct = default);
    Task MarkUsedAsync(PhoneOtpChallenge challenge, CancellationToken ct = default);
    Task RecordFailedAttemptAsync(string channelKey, CancellationToken ct = default);
}
