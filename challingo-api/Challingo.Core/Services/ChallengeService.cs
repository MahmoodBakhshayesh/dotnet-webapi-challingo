using System.Security.Cryptography;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Newtonsoft.Json.Linq;
using Challingo.Core.Competition;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.Enums;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.Challenges;
using Challingo.Core.Puzzles;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services;

/// <summary>
/// The puzzle engine's start / move / submit contract. The server owns the puzzle, the clock and the verdict:
/// the app only ever sees the public puzzle, and elapsed time is server finish minus server start.
/// </summary>
public sealed class ChallengeService(
    IChallengeRepository challenges,
    IPuzzleGameRegistry games,
    IAttemptTokenService tokens,
    ICompetitionService competition,
    IOptions<PuzzleOptions> options,
    TimeProvider clock) : IChallengeService
{
    public async Task<ActionResult<ChallengeResponse>> CreatePracticeAsync(Guid userId, string gameKey, int? difficulty = null)
    {
        var game = games.Find(gameKey);
        if (game is null)
            return AppResponse.NotFound($"Unknown game '{gameKey}'.");

        var level = Math.Clamp(difficulty ?? options.Value.PracticeDifficulty, 1, 4);
        var seed = RandomNumberGenerator.GetInt32(int.MaxValue);
        GeneratedPuzzle generated;
        try
        {
            generated = await game.GenerateAsync(seed, level);
        }
        catch (PuzzleContentUnavailableException ex)
        {
            return AppResponse.RequestError(ex.Message, 503);
        }

        var now = clock.GetUtcNow().UtcDateTime;
        var puzzle = new Puzzle
        {
            Id = Guid.CreateVersion7(),
            GameKey = game.Key,
            Seed = seed,
            Difficulty = level,
            GeneratorVersion = game.GeneratorVersion,
            PublicJson = generated.PublicJson,
            SecretJson = generated.SecretJson,
        };
        var challenge = new Challenge
        {
            Id = Guid.CreateVersion7(),
            Kind = ChallengeKind.Practice,
            PuzzleId = puzzle.Id,
            GameKey = puzzle.GameKey,
            OpensAtUtc = now,
            JoinClosesAtUtc = now.AddMinutes(Math.Max(1, options.Value.PracticeWindowMinutes)),
            ClosesAtUtc = now.AddMinutes(Math.Max(1, options.Value.PracticeWindowMinutes)),
            OwnerUserId = userId,
        };
        await challenges.AddAsync(puzzle, challenge);

        return AppResponse.Ok(new ChallengeResponse
        {
            ChallengeId = challenge.Id,
            Kind = challenge.Kind,
            GameKey = puzzle.GameKey,
            OpensAtUtc = challenge.OpensAtUtc,
            ClosesAtUtc = challenge.ClosesAtUtc,
            Difficulty = level,
        });
    }

    public async Task<ActionResult<StartAttemptResponse>> StartAsync(Guid userId, Guid challengeId)
    {
        var challenge = await challenges.GetChallengeAsync(challengeId);
        if (challenge?.Puzzle is null || (challenge.OwnerUserId is { } owner && owner != userId))
            return AppResponse.NotFound("Challenge not found.");

        var now = clock.GetUtcNow().UtcDateTime;
        if (now < challenge.OpensAtUtc)
            return AppResponse.RequestError("This challenge has not opened yet.", 409);
        if (now >= challenge.ClosesAtUtc)
            return AppResponse.RequestError("This challenge has closed.", 410);

        var attempt = await challenges.GetAttemptAsync(challengeId, userId);
        var resumed = attempt is not null;
        if (attempt is null)
        {
            var entry = challenge.Kind == ChallengeKind.Practice ? null : await competition.CheckEntryAsync(userId, challenge, now);
            if (entry?.Error is { } entryError)
                return AppResponse.RequestError(entryError, entry.StatusCode);

            attempt = new Attempt
            {
                Id = Guid.CreateVersion7(),
                ChallengeId = challengeId,
                UserId = userId,
                Status = AttemptStatus.InProgress,
                StartedAtUtc = now,
                CountryCode = entry?.CountryCode,
            };
            if (!await challenges.TryAddAttemptAsync(attempt))
            {
                // Lost a race with a parallel start from the same player: use the attempt that won.
                attempt = await challenges.GetAttemptAsync(challengeId, userId);
                resumed = true;
                if (attempt is null)
                    return AppResponse.RequestError("Could not start the attempt. Try again.", 409);
            }
        }

        // One attempt per challenge: an unfinished one resumes with its clock still running.
        if (attempt.Status != AttemptStatus.InProgress)
            return AppResponse.RequestError("You have already played this challenge.", 409);

        return AppResponse.Ok(new StartAttemptResponse
        {
            AttemptId = attempt.Id,
            AttemptToken = tokens.Create(attempt.Id, attempt.UserId),
            GameKey = challenge.Puzzle.GameKey,
            Difficulty = challenge.Puzzle.Difficulty,
            Puzzle = JToken.Parse(challenge.Puzzle.PublicJson),
            StartedAtUtc = attempt.StartedAtUtc,
            ClosesAtUtc = challenge.ClosesAtUtc,
            ServerNowUtc = now,
            Resumed = resumed,
            Interactive = games.Find(challenge.Puzzle.GameKey) is IInteractivePuzzleGame,
            State = attempt.StateJson is null ? null : JToken.Parse(attempt.StateJson),
        });
    }

    public async Task<ActionResult<MoveAttemptResponse>> MoveAsync(Guid userId, Guid attemptId, MoveAttemptRequest request)
    {
        var (attempt, error) = await LoadOpenAttemptAsync(userId, attemptId, request.AttemptToken);
        if (error is not null)
            return error;

        var challenge = attempt!.Challenge!;
        var puzzle = challenge.Puzzle!;
        if (games.Find(puzzle.GameKey) is not IInteractivePuzzleGame game)
            return AppResponse.RequestError("This game takes a single submission, not moves.");
        if (request.Move is null)
            return AppResponse.RequestError("Move is required.");

        var now = clock.GetUtcNow().UtcDateTime;
        if (now >= challenge.ClosesAtUtc)
            return await ExpireAsync(attempt, now);

        var result = game.ApplyMove(new PuzzleMove(
            puzzle.PublicJson, puzzle.SecretJson, attempt.StateJson,
            request.Move.ToString(Newtonsoft.Json.Formatting.None), now - attempt.StartedAtUtc));
        if (result.Error is not null)
            return AppResponse.RequestError(result.Error);

        var expected = attempt.MoveCount;
        attempt.StateJson = result.StateJson ?? attempt.StateJson;
        attempt.MoveCount = expected + 1;

        bool saved;
        if (result.Outcome is { } outcome && outcome != PuzzleOutcome.Incorrect)
        {
            attempt.Status = outcome == PuzzleOutcome.Solved ? AttemptStatus.Solved : AttemptStatus.Failed;
            attempt.SubmittedAtUtc = now;
            attempt.ElapsedMs = (long)(now - attempt.StartedAtUtc).TotalMilliseconds;
            attempt.ResultJson = result.ResultJson;
            attempt.RankScore = RankScoreFor(challenge, attempt);
            saved = await challenges.TryCompleteAttemptAsync(attempt, expected);
        }
        else
        {
            saved = await challenges.TrySaveProgressAsync(attempt, expected);
        }

        if (!saved)
            return AppResponse.RequestError("Another move was processed at the same time. Reload and try again.", 409);

        var standing = attempt.Status == AttemptStatus.InProgress ? null : await competition.OnAttemptCompletedAsync(attempt, challenge);
        return AppResponse.Ok(new MoveAttemptResponse
        {
            AttemptId = attempt.Id,
            Status = attempt.Status,
            Response = JToken.Parse(result.ResponseJson),
            MoveCount = attempt.MoveCount,
            ElapsedMs = attempt.Status == AttemptStatus.InProgress ? null : attempt.ElapsedMs,
            Standing = standing,
        });
    }

    public async Task<ActionResult<SubmitAttemptResponse>> SubmitAsync(Guid userId, Guid attemptId, SubmitAttemptRequest request)
    {
        var (attempt, error) = await LoadOpenAttemptAsync(userId, attemptId, request.AttemptToken);
        if (error is not null)
            return error;

        var challenge = attempt!.Challenge!;
        var puzzle = challenge.Puzzle!;
        var now = clock.GetUtcNow().UtcDateTime;
        var expected = attempt.MoveCount;
        attempt.SubmittedAtUtc = now;
        attempt.SubmissionJson = new JObject
        {
            ["submission"] = request.Submission,
            ["moves"] = request.Moves,
        }.ToString(Newtonsoft.Json.Formatting.None);

        if (now >= challenge.ClosesAtUtc)
            return await ExpireAsync(attempt, now);

        var game = games.Find(puzzle.GameKey);
        if (game is null)
            return AppResponse.RequestError($"Game '{puzzle.GameKey}' is not available.", 500);

        var verdict = game.Verify(new PuzzleSubmission(
            puzzle.PublicJson, puzzle.SecretJson, attempt.StateJson,
            (request.Submission ?? new JObject()).ToString(Newtonsoft.Json.Formatting.None),
            now - attempt.StartedAtUtc));

        switch (verdict.Outcome)
        {
            // A malformed submission does not use up the attempt; the app can fix and resend.
            case PuzzleOutcome.Invalid:
                return AppResponse.RequestError(verdict.Message ?? "Invalid submission.");

            // A wrong answer keeps the attempt open; the running clock is the penalty.
            case PuzzleOutcome.Incorrect:
                await challenges.RecordIncorrectSubmissionAsync(attempt.Id);
                return AppResponse.Ok(new SubmitAttemptResponse
                {
                    AttemptId = attempt.Id,
                    Status = AttemptStatus.InProgress,
                    Solved = false,
                    Message = verdict.Message,
                });
        }

        attempt.Status = verdict.Outcome == PuzzleOutcome.Solved ? AttemptStatus.Solved : AttemptStatus.Failed;
        attempt.ElapsedMs = (long)(now - attempt.StartedAtUtc).TotalMilliseconds;
        attempt.ResultJson = verdict.ResultJson;
        attempt.RankScore = RankScoreFor(challenge, attempt);

        if (!await challenges.TryCompleteAttemptAsync(attempt, expected))
            return AppResponse.RequestError("This attempt was already submitted.", 409);

        var standing = await competition.OnAttemptCompletedAsync(attempt, challenge);

        return AppResponse.Ok(new SubmitAttemptResponse
        {
            AttemptId = attempt.Id,
            Status = attempt.Status,
            Solved = attempt.Status == AttemptStatus.Solved,
            ElapsedMs = attempt.ElapsedMs,
            Message = verdict.Message,
            Result = verdict.ResultJson is null ? null : JToken.Parse(verdict.ResultJson),
            Standing = standing,
        });
    }

    private static double? RankScoreFor(Challenge challenge, Attempt attempt) =>
        challenge.Kind == ChallengeKind.Practice
            ? null
            : RankScore.Compute(challenge.GameKey, attempt.Status, attempt.ElapsedMs, attempt.ResultJson);

    private async Task<(Attempt? Attempt, ActionResult? Error)> LoadOpenAttemptAsync(Guid userId, Guid attemptId, string? token)
    {
        var attempt = await challenges.GetAttemptWithPuzzleAsync(attemptId);
        if (attempt?.Challenge?.Puzzle is null || attempt.UserId != userId)
            return (null, AppResponse.NotFound("Attempt not found."));
        if (!tokens.IsValid(token, attempt.Id, userId))
            return (null, AppResponse.Forbidden("Invalid attempt token."));
        if (attempt.Status != AttemptStatus.InProgress)
            return (null, AppResponse.RequestError("This attempt is already finished.", 409));
        return (attempt, null);
    }

    private async Task<ActionResult> ExpireAsync(Attempt attempt, DateTime now)
    {
        attempt.Status = AttemptStatus.Expired;
        attempt.SubmittedAtUtc = now;
        await challenges.TryCompleteAttemptAsync(attempt, attempt.MoveCount);
        return AppResponse.RequestError("This challenge closed before the move arrived.", 410);
    }
}
