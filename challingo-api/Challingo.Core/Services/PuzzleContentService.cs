using System.Security.Cryptography;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json.Linq;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.Enums;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.Content;
using Challingo.Core.Puzzles;
using Challingo.Core.Puzzles.Content;
using Challingo.Core.Puzzles.Games.WordGuess;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Core.Services;

public sealed class PuzzleContentService(
    IPuzzleContentRepository content,
    IEnumerable<IPuzzleContentValidator> validators,
    IPuzzleGameRegistry games,
    TimeProvider clock) : IPuzzleContentService
{
    private const int PageSize = 100;

    public async Task<ActionResult<IReadOnlyList<ContentItemResponse>>> ListAsync(string gameKey, ContentStatus? status, int page)
    {
        if (Validator(gameKey) is null)
            return AppResponse.NotFound($"'{gameKey}' has no reviewed content.");
        var items = await content.ListAsync(gameKey, status, Math.Max(0, page) * PageSize, PageSize);
        return AppResponse.OkList(items.Select(ToResponse));
    }

    public async Task<ActionResult<ContentItemResponse>> AddAsync(string gameKey, AddContentRequest request, Guid reviewerId)
    {
        var validator = Validator(gameKey);
        if (validator is null)
            return AppResponse.NotFound($"'{gameKey}' has no reviewed content.");
        if (request.Payload is null)
            return AppResponse.RequestError("Payload is required.");

        var result = validator.Validate(request.Payload.ToString(Newtonsoft.Json.Formatting.None));
        if (result.Error is not null)
            return AppResponse.RequestError(result.Error);
        if (await content.ExistsAsync(gameKey, result.ContentKey!))
            return AppResponse.RequestError("This item already exists.", 409);

        var item = NewItem(gameKey, result, request.Notes, request.Approve, reviewerId);
        await content.AddRangeAsync([item]);
        return AppResponse.Ok(ToResponse(item));
    }

    public async Task<ActionResult<BulkAddResponse>> AddWordGuessAnswersAsync(BulkWordsRequest request, Guid reviewerId)
    {
        var validator = Validator(WordGuessGame.GameKey)!;
        var words = request.Words
            .Split(['\n', '\r', ',', ' ', '\t'], StringSplitOptions.RemoveEmptyEntries)
            .Select(w => w.Trim().ToLowerInvariant())
            .Distinct()
            .ToList();

        var errors = new List<string>();
        var items = new List<PuzzleContent>();
        var duplicates = 0;
        foreach (var word in words)
        {
            var result = validator.Validate(PuzzleJson.Write(new WordGuessPayload(word)));
            if (result.Error is not null)
                errors.Add(result.Error);
            else if (await content.ExistsAsync(WordGuessGame.GameKey, result.ContentKey!))
                duplicates++;
            else
                items.Add(NewItem(WordGuessGame.GameKey, result, null, request.Approve, reviewerId));
        }
        await content.AddRangeAsync(items);
        return AppResponse.Ok(new BulkAddResponse { Added = items.Count, Duplicates = duplicates, Errors = errors });
    }

    public async Task<ActionResult<ContentItemResponse>> SetStatusAsync(Guid id, ContentStatus status, Guid reviewerId)
    {
        var item = await content.GetAsync(id);
        if (item is null)
            return AppResponse.NotFound();
        item.Status = status;
        item.ReviewedByUserId = reviewerId;
        item.ReviewedAtUtc = clock.GetUtcNow().UtcDateTime;
        await content.SaveAsync(item);
        return AppResponse.Ok(ToResponse(item));
    }

    public async Task<ActionResult<PuzzlePreviewResponse>> PreviewAsync(string gameKey, int? seed, int difficulty)
    {
        var game = games.Find(gameKey);
        if (game is null)
            return AppResponse.NotFound($"Unknown game '{gameKey}'.");

        var usedSeed = seed ?? RandomNumberGenerator.GetInt32(int.MaxValue);
        try
        {
            var puzzle = await game.GenerateAsync(usedSeed, difficulty);
            return AppResponse.Ok(new PuzzlePreviewResponse
            {
                GameKey = game.Key,
                Seed = usedSeed,
                Difficulty = difficulty,
                Puzzle = JToken.Parse(puzzle.PublicJson),
                Secret = JToken.Parse(puzzle.SecretJson),
            });
        }
        catch (PuzzleContentUnavailableException ex)
        {
            return AppResponse.RequestError(ex.Message, 503);
        }
    }

    private IPuzzleContentValidator? Validator(string gameKey) =>
        validators.FirstOrDefault(v => string.Equals(v.GameKey, gameKey, StringComparison.OrdinalIgnoreCase));

    private PuzzleContent NewItem(string gameKey, ContentValidation result, string? notes, bool approve, Guid reviewerId) => new()
    {
        Id = Guid.CreateVersion7(),
        GameKey = gameKey.ToLowerInvariant(),
        ContentKey = result.ContentKey!,
        PayloadJson = result.PayloadJson!,
        Notes = notes,
        Status = approve ? ContentStatus.Approved : ContentStatus.Draft,
        ReviewedByUserId = approve ? reviewerId : null,
        ReviewedAtUtc = approve ? clock.GetUtcNow().UtcDateTime : null,
    };

    private static ContentItemResponse ToResponse(PuzzleContent item) => new()
    {
        Id = item.Id,
        GameKey = item.GameKey,
        ContentKey = item.ContentKey,
        Status = item.Status,
        Payload = JToken.Parse(item.PayloadJson),
        Notes = item.Notes,
        CreatedAt = item.CreatedAt,
        ReviewedAtUtc = item.ReviewedAtUtc,
    };
}
