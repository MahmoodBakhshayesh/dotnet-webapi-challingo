using System.Text.Json;
using System.Text.Json.Nodes;
using Challingo.Core.Puzzles;

namespace Challingo.Tests;

internal static class PuzzleTestHelpers
{
    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public static GeneratedPuzzle Generate(this IPuzzleGame game, int seed, int difficulty) =>
        game.GenerateAsync(seed, difficulty).AsTask().GetAwaiter().GetResult();

    public static PuzzleVerdict Verify(this IPuzzleGame game, GeneratedPuzzle puzzle, object submission,
        string? state = null, TimeSpan? elapsed = null) =>
        game.Verify(new PuzzleSubmission(puzzle.PublicJson, puzzle.SecretJson, state,
            submission as string ?? JsonSerializer.Serialize(submission, Json), elapsed ?? TimeSpan.FromSeconds(30)));

    /// <summary>Plays moves in order, threading the state like the engine does; returns every result.</summary>
    public static List<PuzzleMoveResult> Play(this IInteractivePuzzleGame game, GeneratedPuzzle puzzle,
        IEnumerable<object> moves, TimeSpan? elapsed = null)
    {
        var results = new List<PuzzleMoveResult>();
        string? state = null;
        foreach (var move in moves)
        {
            var result = game.ApplyMove(new PuzzleMove(puzzle.PublicJson, puzzle.SecretJson, state,
                move as string ?? JsonSerializer.Serialize(move, Json), elapsed ?? TimeSpan.FromSeconds(30)));
            results.Add(result);
            if (result.Error is null)
                state = result.StateJson ?? state;
            if (result.Outcome is not null and not PuzzleOutcome.Incorrect)
                break;
        }
        return results;
    }

    public static JsonNode Node(string json) => JsonNode.Parse(json)!;

    public static int[] Ints(string json, string property) =>
        Node(json)[property]!.AsArray().Select(n => n!.GetValue<int>()).ToArray();
}
