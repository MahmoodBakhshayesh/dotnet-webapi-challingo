using Microsoft.EntityFrameworkCore;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.Enums;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Infrastructure.DbContexts;

namespace Challingo.Infrastructure.Repositories;

public sealed class PuzzleContentRepository(AppDbContext db) : IPuzzleContentRepository
{
    public async Task<IReadOnlyList<PuzzleContent>> GetApprovedAsync(string gameKey, CancellationToken ct = default) =>
        await db.PuzzleContents.AsNoTracking()
            .Where(x => x.GameKey == gameKey && x.Status == ContentStatus.Approved)
            .OrderBy(x => x.ContentKey)
            .ToListAsync(ct);

    public async Task<IReadOnlyList<PuzzleContent>> ListAsync(string gameKey, ContentStatus? status, int skip, int take, CancellationToken ct = default) =>
        await db.PuzzleContents.AsNoTracking()
            .Where(x => x.GameKey == gameKey && (status == null || x.Status == status))
            .OrderByDescending(x => x.CreatedAt)
            .Skip(skip).Take(take)
            .ToListAsync(ct);

    public Task<PuzzleContent?> GetAsync(Guid id, CancellationToken ct = default) =>
        db.PuzzleContents.FirstOrDefaultAsync(x => x.Id == id, ct);

    public Task<bool> ExistsAsync(string gameKey, string contentKey, CancellationToken ct = default) =>
        db.PuzzleContents.AnyAsync(x => x.GameKey == gameKey && x.ContentKey == contentKey, ct);

    public async Task AddRangeAsync(IEnumerable<PuzzleContent> items, CancellationToken ct = default)
    {
        db.PuzzleContents.AddRange(items);
        await db.SaveChangesAsync(ct);
    }

    public async Task SaveAsync(PuzzleContent item, CancellationToken ct = default) => await db.SaveChangesAsync(ct);
}
