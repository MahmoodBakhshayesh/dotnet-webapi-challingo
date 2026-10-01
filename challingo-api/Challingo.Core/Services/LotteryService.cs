using System.Security.Cryptography;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Challingo.Core.Competition;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.Competition;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services;

/// <summary>
/// The daily lottery (UTC). The number is drawn ahead and committed by hash; picks close at 14:00; a digit is
/// revealed every hour until 24:00; then the longest match from the first digit splits the pot
/// (no match on digit 1 rolls the pot over to the next day). Free to enter; stars are never sold.
/// </summary>
public sealed class LotteryService(
    ILotteryRepository lottery,
    ICompetitionRepository competition,
    IRealtimeNotifier realtime,
    IOptions<CompetitionOptions> options,
    TimeProvider clock,
    ILogger<LotteryService> logger) : ILotteryService
{
    public async Task<LotteryDto?> GetTodayAsync(Guid userId)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var draw = await lottery.GetDrawAsync(CompetitionCalendar.DayKey(CompetitionCalendar.UtcDate(now)));
        return draw is null ? null : await ToDtoAsync(draw, userId, now);
    }

    public async Task<ActionResult<LotteryDto>> GetTodayResultAsync(Guid userId) =>
        await GetTodayAsync(userId) is { } dto ? AppResponse.Ok(dto) : AppResponse.NotFound("Today's draw is not ready yet.");

    public async Task<ActionResult<LotteryDto>> PickAsync(Guid userId, PickLotteryRequest request)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var day = CompetitionCalendar.UtcDate(now);
        var draw = await lottery.GetDrawAsync(CompetitionCalendar.DayKey(day));
        if (draw is null)
            return AppResponse.NotFound("Today's draw is not ready yet.");
        if (now >= LotteryRules.PicksCloseUtc(day))
            return AppResponse.RequestError("Picks are closed for today. Come back after 00:00 UTC.", 409);

        var number = string.IsNullOrWhiteSpace(request.Number) ? LotteryRules.RandomNumber() : request.Number.Trim();
        if (!LotteryRules.IsValidNumber(number))
            return AppResponse.RequestError($"Pick exactly {LotteryRules.Digits} digits.");

        await lottery.UpsertTicketAsync(new LotteryTicket { DrawId = draw.Id, UserId = userId, Number = number, PickedAtUtc = now });
        return AppResponse.Ok(await ToDtoAsync(draw, userId, now));
    }

    public async Task<ActionResult<List<LotteryDto>>> GetHistoryAsync(Guid userId)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var list = new List<LotteryDto>();
        foreach (var draw in await lottery.GetRecentSettledAsync(14))
            list.Add(await ToDtoAsync(draw, userId, now));
        return AppResponse.Ok(list);
    }

    private async Task<LotteryDto> ToDtoAsync(LotteryDraw draw, Guid userId, DateTime now)
    {
        var day = DateOnly.ParseExact(draw.DayKey, "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);
        var settled = draw.SettledAtUtc is not null;
        var revealedCount = settled ? LotteryRules.Digits : LotteryRules.RevealedCount(day, now);
        var revealed = draw.Number[..revealedCount];
        var ticket = await lottery.GetTicketAsync(draw.Id, userId);
        var match = ticket is null ? 0 : LotteryRules.MatchLength(ticket.Number, draw.Number[..revealedCount]);
        var phase = settled ? LotteryPhase.Settled : now < LotteryRules.PicksCloseUtc(day) ? LotteryPhase.Picking : LotteryPhase.Revealing;

        LotteryResultDto? result = null;
        if (settled)
        {
            var won = ticket is not null && draw.WinningMatch > 0 && LotteryRules.MatchLength(ticket.Number, draw.Number) == draw.WinningMatch;
            result = new LotteryResultDto
            {
                Number = draw.Number,
                Salt = draw.Salt,
                WinningMatch = draw.WinningMatch ?? 0,
                Winners = draw.WinnerCount ?? 0,
                PrizePerWinner = draw.PrizePerWinner ?? 0,
                RolledOver = (draw.WinningMatch ?? 0) == 0,
                MyPrize = won ? draw.PrizePerWinner ?? 0 : 0,
            };
        }

        return new LotteryDto
        {
            DayKey = draw.DayKey,
            Phase = phase,
            PicksCloseAtUtc = LotteryRules.PicksCloseUtc(day),
            NextRevealAtUtc = revealedCount < LotteryRules.Digits && !settled ? LotteryRules.RevealAtUtc(day, revealedCount + 1) : null,
            EndsAtUtc = LotteryRules.RevealAtUtc(day, LotteryRules.Digits),
            Revealed = revealed,
            CommitHash = draw.CommitHash,
            Pot = draw.Pot,
            Players = await lottery.CountTicketsAsync(draw.Id),
            Alive = revealedCount == 0 ? 0 : await lottery.CountMatchingAsync(draw.Id, revealed),
            My = ticket is null ? null : new LotteryTicketDto
            {
                Number = ticket.Number,
                Match = match,
                Alive = revealedCount > 0 && match == revealedCount,
            },
            Result = result,
        };
    }

    public async Task<int> EnsureDrawsAsync(DateTime nowUtc, CancellationToken ct = default)
    {
        var created = 0;
        var today = CompetitionCalendar.UtcDate(nowUtc);
        foreach (var day in new[] { today, today.AddDays(1) })
        {
            var dayKey = CompetitionCalendar.DayKey(day);
            if (await lottery.GetDrawAsync(dayKey, ct) is not null)
                continue;
            var number = LotteryRules.RandomNumber();
            var salt = Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(16));
            if (await lottery.TryAddDrawAsync(new LotteryDraw
                {
                    Id = Guid.CreateVersion7(),
                    DayKey = dayKey,
                    Number = number,
                    Salt = salt,
                    CommitHash = LotteryRules.Commit(salt, number),
                    Pot = options.Value.LotteryPot,
                }, ct))
                created++;
        }
        return created;
    }

    public async Task<(int Digits, bool Settled)> RunAsync(DateTime nowUtc, CancellationToken ct = default)
    {
        var digits = 0;
        var today = CompetitionCalendar.UtcDate(nowUtc);
        var draw = await lottery.GetDrawAsync(CompetitionCalendar.DayKey(today), ct);
        if (draw is not null && draw.SettledAtUtc is null)
        {
            var count = LotteryRules.RevealedCount(today, nowUtc);
            if (count > draw.AnnouncedDigits)
            {
                await lottery.SetAnnouncedDigitsAsync(draw.Id, count, ct);
                await realtime.ToAllAsync("lottery.digit", new
                {
                    dayKey = draw.DayKey,
                    revealed = draw.Number[..count],
                    alive = await lottery.CountMatchingAsync(draw.Id, draw.Number[..count], ct),
                }, ct);
                digits = count - draw.AnnouncedDigits;
            }
        }

        var settled = false;
        // A draw is done when its last digit is out: 24:00 of its day, i.e. any day before today.
        foreach (var due in await lottery.ListSettleDueAsync(CompetitionCalendar.DayStartUtc(today), ct))
            settled |= await SettleAsync(due, nowUtc, ct);
        return (digits, settled);
    }

    private async Task<bool> SettleAsync(LotteryDraw due, DateTime nowUtc, CancellationToken ct)
    {
        // Re-read: an earlier draw settled in this same pass may have rolled its pot into this one.
        if (await lottery.GetDrawAsync(due.DayKey, ct) is not { SettledAtUtc: null } draw)
            return false;

        // Longest prefix that at least one ticket shares.
        var match = 0;
        for (var length = LotteryRules.Digits; length >= 1; length--)
        {
            if (await lottery.CountMatchingAsync(draw.Id, draw.Number[..length], ct) > 0)
            {
                match = length;
                break;
            }
        }

        var winners = match == 0 ? [] : await lottery.GetMatchingUsersAsync(draw.Id, draw.Number[..match], ct);
        // Winners matched exactly `match` digits (nobody matched more, by construction).
        var prize = winners.Count == 0 ? 0 : draw.Pot / winners.Count;
        if (!await lottery.TryMarkSettledAsync(draw.Id, match, winners.Count, prize, nowUtc, ct))
            return false;

        if (winners.Count == 0)
        {
            // Nobody matched the first digit: the pot joins the next draw.
            var day = DateOnly.ParseExact(draw.DayKey, "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);
            await EnsureDrawsAsync(CompetitionCalendar.DayStartUtc(day.AddDays(1)), ct);
            if (await lottery.GetDrawAsync(CompetitionCalendar.DayKey(day.AddDays(1)), ct) is { } next)
                await lottery.AddToPotAsync(next.Id, draw.Pot, ct);
        }
        else
        {
            foreach (var userId in winners)
            {
                if (prize > 0 && await competition.TryAwardStarsAsync(userId, prize, $"lottery:{draw.DayKey}", ct))
                    await realtime.ToUserAsync(userId.ToString(), "stars.awarded", new { amount = prize, lottery = draw.DayKey, match }, ct);
            }
        }

        await realtime.ToAllAsync("lottery.settled", new { dayKey = draw.DayKey, number = draw.Number, match, winners = winners.Count, prize }, ct);
        logger.LogInformation("Lottery {Day}: match {Match}, {Winners} winners, {Prize} stars each", draw.DayKey, match, winners.Count, prize);
        return true;
    }
}
