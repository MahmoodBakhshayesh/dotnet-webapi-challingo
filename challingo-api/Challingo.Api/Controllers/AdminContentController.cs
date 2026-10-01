using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Challingo.Api.Extensions;
using Challingo.Core.Domain.Enums;
using Challingo.Core.DTO.Content;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Api.Controllers;

/// <summary>Admin panel: review Word Guess answers and crosswords, preview any game's puzzles.</summary>
[Authorize(Roles = Roles.Admin)]
[Route("api/admin")]
public class AdminContentController(IPuzzleContentService content) : AppController
{
    [HttpGet("content/{gameKey}")]
    public Task<ActionResult<IReadOnlyList<ContentItemResponse>>> List(string gameKey, [FromQuery] ContentStatus? status, [FromQuery] int page = 0) =>
        content.ListAsync(gameKey, status, page);

    [HttpPost("content/{gameKey}")]
    public async Task<ActionResult<ContentItemResponse>> Add(string gameKey, AddContentRequest request) =>
        User.GetUserId() is { } id ? await content.AddAsync(gameKey, request, id) : Unauthorized();

    /// <summary>Paste many Word Guess answers at once (new lines, commas or spaces between words).</summary>
    [HttpPost("content/word-guess/bulk")]
    public async Task<ActionResult<BulkAddResponse>> AddWordGuessAnswers(BulkWordsRequest request) =>
        User.GetUserId() is { } id ? await content.AddWordGuessAnswersAsync(request, id) : Unauthorized();

    [HttpPost("content/items/{id:guid}/approve")]
    public async Task<ActionResult<ContentItemResponse>> Approve(Guid id) =>
        User.GetUserId() is { } user ? await content.SetStatusAsync(id, ContentStatus.Approved, user) : Unauthorized();

    [HttpPost("content/items/{id:guid}/retire")]
    public async Task<ActionResult<ContentItemResponse>> Retire(Guid id) =>
        User.GetUserId() is { } user ? await content.SetStatusAsync(id, ContentStatus.Retired, user) : Unauthorized();

    /// <summary>Generates a puzzle without storing it, solution included — for checking a game before it goes live.</summary>
    [HttpGet("puzzles/{gameKey}/preview")]
    public Task<ActionResult<PuzzlePreviewResponse>> Preview(string gameKey, [FromQuery] int? seed, [FromQuery] int difficulty = 1) =>
        content.PreviewAsync(gameKey, seed, difficulty);
}
