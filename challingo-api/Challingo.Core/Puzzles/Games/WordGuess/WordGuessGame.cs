using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.Puzzles.Content;
using Challingo.Core.Puzzles.Words;

namespace Challingo.Core.Puzzles.Games.WordGuess;

/// <summary>
/// Guess the hidden 5-letter word in 6 tries; each letter comes back <c>correct</c>, <c>present</c> or
/// <c>absent</c>. Answers come from reviewed content; guesses must be dictionary words.
/// Public: <c>{length, maxGuesses}</c>; move: <c>{guess:"crane"}</c>.
/// </summary>
public sealed class WordGuessGame(IPuzzleContentRepository content, IWordDictionary dictionary) : IInteractivePuzzleGame
{
    public const string GameKey = "word-guess";
    private const int Length = 5;
    private const int MaxGuesses = 6;

    public string Key => GameKey;
    public int GeneratorVersion => 1;

    public async ValueTask<GeneratedPuzzle> GenerateAsync(int seed, int difficulty, CancellationToken ct = default)
    {
        var answers = await content.GetApprovedAsync(Key, ct);
        if (answers.Count == 0)
            throw new PuzzleContentUnavailableException("No approved Word Guess answers yet.");

        var pick = answers[new Random(seed).Next(answers.Count)];
        var answer = PuzzleJson.Read<WordGuessPayload>(pick.PayloadJson).Word;
        return new GeneratedPuzzle(
            PuzzleJson.Write(new Public(Length, MaxGuesses)),
            PuzzleJson.Write(new Secret(answer)));
    }

    public PuzzleMoveResult ApplyMove(PuzzleMove move)
    {
        var answer = PuzzleJson.Read<Secret>(move.SecretJson).Answer;
        var state = move.StateJson is null ? new State([]) : PuzzleJson.Read<State>(move.StateJson);

        var guess = WordDictionary.Normalize(PuzzleJson.TryRead<Move>(move.MoveJson)?.Guess);
        if (guess is null || guess.Length != Length)
            return PuzzleMoveResult.Invalid($"A guess is a {Length}-letter word.");
        if (guess != answer && dictionary.IsLoaded && !dictionary.Contains(guess))
            return PuzzleMoveResult.Invalid("Not in the word list.");
        if (state.Guesses.Count >= MaxGuesses)
            return PuzzleMoveResult.Invalid("No guesses left.");

        var marks = Mark(answer, guess);
        var guesses = state.Guesses.Append(new Feedback(guess, marks)).ToList();
        var solved = guess == answer;
        var over = solved || guesses.Count >= MaxGuesses;

        return new PuzzleMoveResult(
            PuzzleJson.Write(new State(guesses)),
            PuzzleJson.Write(new { marks, remaining = MaxGuesses - guesses.Count, answer = over ? answer : null }),
            over ? (solved ? PuzzleOutcome.Solved : PuzzleOutcome.Failed) : null,
            over ? PuzzleJson.Write(new { guesses = guesses.Count }) : null);
    }

    /// <summary>Submitting without the word means giving up.</summary>
    public PuzzleVerdict Verify(PuzzleSubmission submission)
    {
        var guesses = submission.StateJson is null ? 0 : PuzzleJson.Read<State>(submission.StateJson).Guesses.Count;
        return PuzzleVerdict.Failed(PuzzleJson.Write(new { guesses }), "Gave up.");
    }

    /// <summary>Exact matches first, then "present" only while unmatched copies of that letter remain.</summary>
    public static string[] Mark(string answer, string guess)
    {
        var marks = new string[guess.Length];
        var remaining = new int[26];
        for (var i = 0; i < guess.Length; i++)
        {
            if (guess[i] == answer[i])
                marks[i] = "correct";
            else
                remaining[answer[i] - 'a']++;
        }
        for (var i = 0; i < guess.Length; i++)
        {
            if (marks[i] is not null)
                continue;
            var k = guess[i] - 'a';
            marks[i] = remaining[k] > 0 ? "present" : "absent";
            if (remaining[k] > 0)
                remaining[k]--;
        }
        return marks;
    }

    private sealed record Public(int Length, int MaxGuesses);
    private sealed record Secret(string Answer);
    private sealed record Move(string? Guess);
    private sealed record Feedback(string Guess, string[] Marks);
    private sealed record State(List<Feedback> Guesses);
}

public sealed record WordGuessPayload(string Word);

/// <summary>A Word Guess answer: 5 letters a–z, and a dictionary word when the dictionary is loaded.</summary>
public sealed class WordGuessContentValidator(IWordDictionary dictionary) : IPuzzleContentValidator
{
    public string GameKey => WordGuessGame.GameKey;

    public ContentValidation Validate(string payloadJson)
    {
        var word = WordDictionary.Normalize(PuzzleJson.TryRead<WordGuessPayload>(payloadJson)?.Word);
        if (word is not { Length: 5 })
            return ContentValidation.Fail("The answer must be a 5-letter word (a–z).");
        if (dictionary.IsLoaded && !dictionary.Contains(word))
            return ContentValidation.Fail($"'{word}' is not in the word list.");
        return ContentValidation.Ok(PuzzleJson.Write(new WordGuessPayload(word)), word);
    }
}
