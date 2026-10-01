using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.Enums;

namespace Challingo.Core.Domain.RepositoryInterfaces;

public interface IPuzzleContentRepository
{
    /// <summary>Approved items of a game, ordered by <see cref="PuzzleContent.ContentKey"/> (stable for seeded picks).</summary>
    Task<IReadOnlyList<PuzzleContent>> GetApprovedAsync(string gameKey, CancellationToken ct = default);

    Task<IReadOnlyList<PuzzleContent>> ListAsync(string gameKey, ContentStatus? status, int skip, int take, CancellationToken ct = default);
    Task<PuzzleContent?> GetAsync(Guid id, CancellationToken ct = default);
    Task<bool> ExistsAsync(string gameKey, string contentKey, CancellationToken ct = default);
    Task AddRangeAsync(IEnumerable<PuzzleContent> items, CancellationToken ct = default);
    Task SaveAsync(PuzzleContent item, CancellationToken ct = default);
}
