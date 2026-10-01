using Microsoft.EntityFrameworkCore;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Infrastructure.DbContexts;

namespace Challingo.Infrastructure.Repositories;

public sealed class PlayerProfileRepository(AppDbContext db) : IPlayerProfileRepository
{
    public Task<PlayerProfile?> GetByUserIdAsync(Guid userId, CancellationToken ct = default) =>
        db.PlayerProfiles.FirstOrDefaultAsync(x => x.UserId == userId, ct);

    public async Task AddAsync(PlayerProfile profile, CancellationToken ct = default)
    {
        db.PlayerProfiles.Add(profile);
        await db.SaveChangesAsync(ct);
    }

    public async Task SaveAsync(PlayerProfile profile, CancellationToken ct = default)
    {
        if (db.Entry(profile).State == EntityState.Detached)
            db.PlayerProfiles.Update(profile);
        await db.SaveChangesAsync(ct);
    }
}
