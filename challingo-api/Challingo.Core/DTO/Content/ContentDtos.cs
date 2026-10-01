using Challingo.Core.Domain.Enums;
using Newtonsoft.Json.Linq;

namespace Challingo.Core.DTO.Content;

public sealed class ContentItemResponse
{
    public Guid Id { get; init; }
    public required string GameKey { get; init; }
    public required string ContentKey { get; init; }
    public ContentStatus Status { get; init; }
    public required JToken Payload { get; init; }
    public string? Notes { get; init; }
    public DateTime CreatedAt { get; init; }
    public DateTime? ReviewedAtUtc { get; init; }
}

public sealed class AddContentRequest
{
    /// <summary>Game-specific payload, e.g. <c>{"word":"crane"}</c> or a crossword's rows and clues.</summary>
    public JToken? Payload { get; set; }
    public string? Notes { get; set; }

    /// <summary>Approve right away instead of leaving a draft.</summary>
    public bool Approve { get; set; }
}

public sealed class BulkWordsRequest
{
    /// <summary>Words separated by new lines, commas or spaces.</summary>
    public string Words { get; set; } = "";
    public bool Approve { get; set; }
}

public sealed class BulkAddResponse
{
    public int Added { get; init; }
    public int Duplicates { get; init; }
    public required IReadOnlyList<string> Errors { get; init; }
}

public sealed class PuzzlePreviewResponse
{
    public required string GameKey { get; init; }
    public int Seed { get; init; }
    public int Difficulty { get; init; }
    public required JToken Puzzle { get; init; }

    /// <summary>The server-only part (solution, answer). Admin preview only.</summary>
    public required JToken Secret { get; init; }
}
