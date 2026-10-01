using Challingo.Core.Domain.Entities;

namespace Challingo.Core.Domain.RepositoryInterfaces;

public interface IMonetizationRepository
{
    Task<int> CountAdRewardsAsync(Guid userId, string dayKey, CancellationToken ct = default);

    /// <summary>False when the transaction was already rewarded.</summary>
    Task<bool> TryAddAdRewardAsync(AdReward reward, CancellationToken ct = default);

    Task<PlusEntitlement?> GetEntitlementAsync(Guid userId, CancellationToken ct = default);
    Task UpsertEntitlementAsync(PlusEntitlement entitlement, CancellationToken ct = default);
}
