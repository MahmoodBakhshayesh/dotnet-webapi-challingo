using Microsoft.AspNetCore.Mvc;
using Challingo.Core.Domain.Enums;
using Challingo.Core.DTO.Content;

namespace Challingo.Core.ServiceInterfaces;

/// <summary>Admin review of content-based games (Word Guess answers, crosswords) and puzzle previews.</summary>
public interface IPuzzleContentService
{
    Task<ActionResult<IReadOnlyList<ContentItemResponse>>> ListAsync(string gameKey, ContentStatus? status, int page);
    Task<ActionResult<ContentItemResponse>> AddAsync(string gameKey, AddContentRequest request, Guid reviewerId);
    Task<ActionResult<BulkAddResponse>> AddWordGuessAnswersAsync(BulkWordsRequest request, Guid reviewerId);
    Task<ActionResult<ContentItemResponse>> SetStatusAsync(Guid id, ContentStatus status, Guid reviewerId);
    Task<ActionResult<PuzzlePreviewResponse>> PreviewAsync(string gameKey, int? seed, int difficulty);
}
