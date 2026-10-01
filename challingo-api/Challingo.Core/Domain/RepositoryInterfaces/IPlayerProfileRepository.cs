using Challingo.Core.Domain.Entities;

namespace Challingo.Core.Domain.RepositoryInterfaces;

public interface IPlayerProfileRepository
{
    Task<PlayerProfile?> GetByUserIdAsync(Guid userId, CancellationToken ct = default);
    Task AddAsync(PlayerProfile profile, CancellationToken ct = default);
    Task SaveAsync(PlayerProfile profile, CancellationToken ct = default);
}
