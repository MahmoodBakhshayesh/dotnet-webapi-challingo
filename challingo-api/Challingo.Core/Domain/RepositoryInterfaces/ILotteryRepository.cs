using Challingo.Core.Domain.Entities;

namespace Challingo.Core.Domain.RepositoryInterfaces;

public interface ILotteryRepository
{
    Task<LotteryDraw?> GetDrawAsync(string dayKey, CancellationToken ct = default);

    /// <summary>False if the day already has a draw.</summary>
    Task<bool> TryAddDrawAsync(LotteryDraw draw, CancellationToken ct = default);

    /// <summary>Adds rolled-over stars to a draw's pot.</summary>
    Task AddToPotAsync(Guid drawId, int stars, CancellationToken ct = default);

    Task<LotteryTicket?> GetTicketAsync(Guid drawId, Guid userId, CancellationToken ct = default);

    /// <summary>Inserts the player's pick or replaces it.</summary>
    Task UpsertTicketAsync(LotteryTicket ticket, CancellationToken ct = default);

    Task<int> CountTicketsAsync(Guid drawId, CancellationToken ct = default);

    /// <summary>Tickets whose number starts with <paramref name="prefix"/> (all tickets for an empty prefix).</summary>
    Task<int> CountMatchingAsync(Guid drawId, string prefix, CancellationToken ct = default);

    Task<List<Guid>> GetMatchingUsersAsync(Guid drawId, string prefix, CancellationToken ct = default);

    Task SetAnnouncedDigitsAsync(Guid drawId, int digits, CancellationToken ct = default);

    /// <summary>Marks the draw settled; false if another run settled it first.</summary>
    Task<bool> TryMarkSettledAsync(Guid drawId, int winningMatch, int winners, int prizePerWinner, DateTime nowUtc, CancellationToken ct = default);

    /// <summary>Unsettled draws whose last digit is out.</summary>
    Task<List<LotteryDraw>> ListSettleDueAsync(DateTime dayEndBeforeUtc, CancellationToken ct = default);

    Task<List<LotteryDraw>> GetRecentSettledAsync(int count, CancellationToken ct = default);
}
