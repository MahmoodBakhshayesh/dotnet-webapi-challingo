using Microsoft.EntityFrameworkCore;
using Npgsql;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Infrastructure.DbContexts;

namespace Challingo.Infrastructure.Repositories;

public sealed class MonetizationRepository(AppDbContext db) : IMonetizationRepository
{
    public Task<int> CountAdRewardsAsync(Guid userId, string dayKey, CancellationToken ct = default) =>
        db.AdRewards.CountAsync(a => a.UserId == userId && a.DayKey == dayKey, ct);

    public async Task<bool> TryAddAdRewardAsync(AdReward reward, CancellationToken ct = default)
    {
        db.AdRewards.Add(reward);
        try
        {
            await db.SaveChangesAsync(ct);
            return true;
        }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            db.Entry(reward).State = EntityState.Detached;
            return false;
        }
    }

    public Task<PlusEntitlement?> GetEntitlementAsync(Guid userId, CancellationToken ct = default) =>
        db.PlusEntitlements.AsNoTracking().FirstOrDefaultAsync(e => e.UserId == userId, ct);

    public Task UpsertEntitlementAsync(PlusEntitlement e, CancellationToken ct = default) =>
        db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO "PlusEntitlements" ("UserId", "Active", "ExpiresAtUtc", "ProductId", "Store", "UpdatedAtUtc")
            VALUES ({e.UserId}, {e.Active}, {e.ExpiresAtUtc}, {e.ProductId}, {e.Store}, {e.UpdatedAtUtc})
            ON CONFLICT ("UserId") DO UPDATE SET "Active" = EXCLUDED."Active", "ExpiresAtUtc" = EXCLUDED."ExpiresAtUtc",
                "ProductId" = EXCLUDED."ProductId", "Store" = EXCLUDED."Store", "UpdatedAtUtc" = EXCLUDED."UpdatedAtUtc"
            """, ct);
}
