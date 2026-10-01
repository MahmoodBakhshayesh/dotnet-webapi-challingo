using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Challingo.Core.Competition;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.Competition;
using Challingo.Core.Puzzles;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services;

/// <summary>Admin view of the schedule: preview, swap a puzzle before it opens, run the jobs now.</summary>
public sealed class ScheduleAdminService(
    ICompetitionRepository competition,
    ICompetitionScheduler scheduler,
    ICompetitionCloser closer,
    IPuzzleGameRegistry games,
    IOptions<CompetitionOptions> options,
    TimeProvider clock) : IScheduleAdminService
{
    public async Task<ActionResult<List<ScheduleEntryDto>>> ListAsync(DateTime fromUtc, DateTime toUtc)
    {
        if (toUtc <= fromUtc || toUtc - fromUtc > TimeSpan.FromDays(31))
            return AppResponse.RequestError("Pick a range of up to 31 days.");
        var challenges = await competition.ListChallengesAsync(fromUtc, toUtc);
        var counts = await competition.CountAttemptsAsync(challenges.Select(c => c.Id).ToList());
        var now = clock.GetUtcNow().UtcDateTime;
        return AppResponse.Ok(challenges.Select(c => ToDto(c, now, counts.GetValueOrDefault(c.Id))).ToList());
    }

    public async Task<ActionResult<ScheduleEntryDto>> SwapAsync(Guid challengeId, SwapPuzzleRequest request)
    {
        var challenge = await competition.GetChallengeAsync(challengeId);
        if (challenge?.Puzzle is null || challenge.SlotKey is null)
            return AppResponse.NotFound("Scheduled challenge not found.");

        var now = clock.GetUtcNow().UtcDateTime;
        var attempts = (await competition.CountAttemptsAsync([challengeId])).GetValueOrDefault(challengeId);
        if (challenge.OpensAtUtc <= now || attempts > 0)
            return AppResponse.RequestError("Only challenges that have not opened yet can be swapped.", 409);

        var gameKey = request.GameKey?.Trim();
        if (string.IsNullOrEmpty(gameKey))
        {
            var others = games.Keys.Where(k => k != challenge.Puzzle.GameKey).ToList();
            gameKey = others[Random.Shared.Next(others.Count)];
        }
        var game = games.Find(gameKey);
        if (game is null)
            return AppResponse.NotFound($"Unknown game '{gameKey}'.");

        Puzzle puzzle;
        try
        {
            var seed = System.Security.Cryptography.RandomNumberGenerator.GetInt32(int.MaxValue);
            var generated = await game.GenerateAsync(seed, challenge.Puzzle.Difficulty);
            puzzle = new Puzzle
            {
                Id = Guid.CreateVersion7(),
                GameKey = game.Key,
                Seed = seed,
                Difficulty = challenge.Puzzle.Difficulty,
                GeneratorVersion = game.GeneratorVersion,
                PublicJson = generated.PublicJson,
                SecretJson = generated.SecretJson,
            };
        }
        catch (PuzzleContentUnavailableException ex)
        {
            return AppResponse.RequestError(ex.Message, 503);
        }

        await competition.ReplacePuzzleAsync(challengeId, puzzle);
        challenge.Puzzle = puzzle;
        challenge.PuzzleId = puzzle.Id;
        return AppResponse.Ok(ToDto(challenge, now, 0));
    }

    public async Task<ActionResult<ScheduleEntryDto>> SetWindowAsync(Guid challengeId, SetWindowRequest request)
    {
        if (!options.Value.AllowAdminTimeTravel)
            return AppResponse.Forbidden("Moving challenge windows is disabled (Competition__AllowAdminTimeTravel).");
        if (request.ClosesAtUtc <= request.OpensAtUtc)
            return AppResponse.RequestError("ClosesAtUtc must be after OpensAtUtc.");
        var challenge = await competition.GetChallengeAsync(challengeId);
        if (challenge?.SlotKey is null)
            return AppResponse.NotFound("Scheduled challenge not found.");
        if (challenge.FinalizedAtUtc is not null)
            return AppResponse.RequestError("This challenge is already finalized.", 409);

        var opens = DateTime.SpecifyKind(request.OpensAtUtc.ToUniversalTime(), DateTimeKind.Utc);
        var closes = DateTime.SpecifyKind(request.ClosesAtUtc.ToUniversalTime(), DateTimeKind.Utc);
        await competition.SetWindowAsync(challengeId, opens, closes);
        challenge.OpensAtUtc = opens;
        challenge.ClosesAtUtc = closes;
        var attempts = (await competition.CountAttemptsAsync([challengeId])).GetValueOrDefault(challengeId);
        return AppResponse.Ok(ToDto(challenge, clock.GetUtcNow().UtcDateTime, attempts));
    }

    public async Task<ActionResult<CompetitionRunResponse>> RunNowAsync()
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var scheduled = await scheduler.EnsureScheduleAsync(now);
        var run = await closer.RunAsync(now);
        return AppResponse.Ok(new CompetitionRunResponse
        {
            Scheduled = scheduled,
            Announced = run.Announced,
            Finalized = run.Finalized,
            DaysClosed = run.DaysClosed,
            WeeksClosed = run.WeeksClosed,
        });
    }

    private static ScheduleEntryDto ToDto(Challenge c, DateTime now, int attempts) => new()
    {
        ChallengeId = c.Id,
        Kind = c.Kind,
        SlotKey = c.SlotKey ?? "",
        Sequence = c.Sequence,
        GameKey = c.Puzzle?.GameKey ?? "",
        Difficulty = c.Puzzle?.Difficulty ?? 0,
        LocalDate = c.LocalDate,
        OpensAtUtc = c.OpensAtUtc,
        ClosesAtUtc = c.ClosesAtUtc,
        State = CompetitionService.StateAt(c, now),
        Attempts = attempts,
        Finalized = c.FinalizedAtUtc is not null,
    };
}
