using Microsoft.EntityFrameworkCore;
using Npgsql;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Infrastructure.DbContexts;

namespace Challingo.Infrastructure.Repositories;

public sealed class LotteryRepository(AppDbContext db) : ILotteryRepository
{
    public Task<LotteryDraw?> GetDrawAsync(string dayKey, CancellationToken ct = default) =>
        db.LotteryDraws.AsNoTracking().FirstOrDefaultAsync(d => d.DayKey == dayKey, ct);

    public async Task<bool> TryAddDrawAsync(LotteryDraw draw, CancellationToken ct = default)
    {
        db.LotteryDraws.Add(draw);
        try
        {
            await db.SaveChangesAsync(ct);
            return true;
        }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            db.Entry(draw).State = EntityState.Detached;
            return false;
        }
    }

    public Task AddToPotAsync(Guid drawId, int stars, CancellationToken ct = default) =>
        db.LotteryDraws.Where(d => d.Id == drawId).ExecuteUpdateAsync(s => s.SetProperty(d => d.Pot, d => d.Pot + stars), ct);

    public Task<LotteryTicket?> GetTicketAsync(Guid drawId, Guid userId, CancellationToken ct = default) =>
        db.LotteryTickets.AsNoTracking().FirstOrDefaultAsync(t => t.DrawId == drawId && t.UserId == userId, ct);

    public Task UpsertTicketAsync(LotteryTicket ticket, CancellationToken ct = default) =>
        db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO "LotteryTickets" ("DrawId", "UserId", "Number", "PickedAtUtc")
            VALUES ({ticket.DrawId}, {ticket.UserId}, {ticket.Number}, {ticket.PickedAtUtc})
            ON CONFLICT ("DrawId", "UserId") DO UPDATE SET "Number" = EXCLUDED."Number", "PickedAtUtc" = EXCLUDED."PickedAtUtc"
            """, ct);

    public Task<int> CountTicketsAsync(Guid drawId, CancellationToken ct = default) =>
        db.LotteryTickets.CountAsync(t => t.DrawId == drawId, ct);

    public Task<int> CountMatchingAsync(Guid drawId, string prefix, CancellationToken ct = default) =>
        db.LotteryTickets.CountAsync(t => t.DrawId == drawId && t.Number.StartsWith(prefix), ct);

    public Task<List<Guid>> GetMatchingUsersAsync(Guid drawId, string prefix, CancellationToken ct = default) =>
        db.LotteryTickets.Where(t => t.DrawId == drawId && t.Number.StartsWith(prefix)).Select(t => t.UserId).ToListAsync(ct);

    public Task SetAnnouncedDigitsAsync(Guid drawId, int digits, CancellationToken ct = default) =>
        db.LotteryDraws.Where(d => d.Id == drawId && d.AnnouncedDigits < digits)
            .ExecuteUpdateAsync(s => s.SetProperty(d => d.AnnouncedDigits, digits), ct);

    public async Task<bool> TryMarkSettledAsync(Guid drawId, int winningMatch, int winners, int prizePerWinner, DateTime nowUtc, CancellationToken ct = default) =>
        await db.LotteryDraws.Where(d => d.Id == drawId && d.SettledAtUtc == null)
            .ExecuteUpdateAsync(s => s
                .SetProperty(d => d.SettledAtUtc, nowUtc)
                .SetProperty(d => d.AnnouncedDigits, 10)
                .SetProperty(d => d.WinningMatch, winningMatch)
                .SetProperty(d => d.WinnerCount, winners)
                .SetProperty(d => d.PrizePerWinner, prizePerWinner), ct) == 1;

    public async Task<List<LotteryDraw>> ListSettleDueAsync(DateTime dayEndBeforeUtc, CancellationToken ct = default)
    {
        // DayKey is yyyy-MM-dd, so string order is date order.
        var before = dayEndBeforeUtc.ToString("yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);
        return await db.LotteryDraws.AsNoTracking()
            .Where(d => d.SettledAtUtc == null && string.Compare(d.DayKey, before) < 0)
            .OrderBy(d => d.DayKey)
            .ToListAsync(ct);
    }

    public Task<List<LotteryDraw>> GetRecentSettledAsync(int count, CancellationToken ct = default) =>
        db.LotteryDraws.AsNoTracking().Where(d => d.SettledAtUtc != null)
            .OrderByDescending(d => d.DayKey).Take(count).ToListAsync(ct);
}
