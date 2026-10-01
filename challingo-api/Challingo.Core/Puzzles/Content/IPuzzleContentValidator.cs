namespace Challingo.Core.Puzzles.Content;

/// <summary>Checks one content item for a content-based game before it is stored.</summary>
public interface IPuzzleContentValidator
{
    string GameKey { get; }

    /// <summary>Normalised payload + its unique key, or an error message.</summary>
    ContentValidation Validate(string payloadJson);
}

public sealed record ContentValidation(string? PayloadJson, string? ContentKey, string? Error)
{
    public static ContentValidation Ok(string payloadJson, string contentKey) => new(payloadJson, contentKey, null);
    public static ContentValidation Fail(string error) => new(null, null, error);
}
