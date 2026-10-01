using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.Enums;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.Puzzles;
using Challingo.Core.Puzzles.Games.MiniCrossword;
using Challingo.Core.Puzzles.Games.WordGuess;
using Challingo.Core.Puzzles.Games.WordHunt;
using Challingo.Core.Puzzles.Words;
using Xunit;
using static Challingo.Tests.PuzzleTestHelpers;

namespace Challingo.Tests;

internal sealed class FakeContent(params PuzzleContent[] items) : IPuzzleContentRepository
{
    private readonly List<PuzzleContent> _items = items.ToList();

    public static PuzzleContent Item(string game, string key, string payload) =>
        new() { Id = Guid.NewGuid(), GameKey = game, ContentKey = key, PayloadJson = payload, Status = ContentStatus.Approved };

    public Task<IReadOnlyList<PuzzleContent>> GetApprovedAsync(string gameKey, CancellationToken ct = default) =>
        Task.FromResult<IReadOnlyList<PuzzleContent>>(_items.Where(i => i.GameKey == gameKey && i.Status == ContentStatus.Approved).OrderBy(i => i.ContentKey).ToList());
    public Task<IReadOnlyList<PuzzleContent>> ListAsync(string gameKey, ContentStatus? status, int skip, int take, CancellationToken ct = default) =>
        Task.FromResult<IReadOnlyList<PuzzleContent>>(_items);
    public Task<PuzzleContent?> GetAsync(Guid id, CancellationToken ct = default) => Task.FromResult(_items.FirstOrDefault(i => i.Id == id));
    public Task<bool> ExistsAsync(string gameKey, string contentKey, CancellationToken ct = default) => Task.FromResult(_items.Any(i => i.ContentKey == contentKey));
    public Task AddRangeAsync(IEnumerable<PuzzleContent> items, CancellationToken ct = default) { _items.AddRange(items); return Task.CompletedTask; }
    public Task SaveAsync(PuzzleContent item, CancellationToken ct = default) => Task.CompletedTask;
}

public class WordGuessTests
{
    private static readonly WordDictionary Words = new(["crane", "react", "eerie", "lever", "trace", "slate"]);

    [Theory]
    [InlineData("crane", "react", "present,present,correct,present,absent")]
    [InlineData("lever", "eerie", "present,correct,present,absent,absent")]
    [InlineData("crane", "crane", "correct,correct,correct,correct,correct")]
    public void Marks_handle_repeated_letters(string answer, string guess, string expected) =>
        Assert.Equal(expected, string.Join(",", WordGuessGame.Mark(answer, guess)));

    [Fact]
    public void Plays_to_a_solve_and_rejects_unknown_words()
    {
        var game = new WordGuessGame(new FakeContent(FakeContent.Item("word-guess", "crane", """{"word":"crane"}""")), Words);
        var puzzle = game.Generate(1, 1);
        Assert.DoesNotContain("crane", puzzle.PublicJson);

        Assert.NotNull(game.Play(puzzle, [new { guess = "zzzzz" }])[0].Error);
        var results = game.Play(puzzle, [new { guess = "slate" }, new { guess = "crane" }]);
        Assert.Null(results[0].Outcome);
        Assert.Equal(PuzzleOutcome.Solved, results[1].Outcome);
    }

    [Fact]
    public void Without_approved_answers_the_game_is_unavailable()
    {
        var game = new WordGuessGame(new FakeContent(), Words);
        Assert.Throws<PuzzleContentUnavailableException>(() => game.Generate(1, 1));
    }

    [Fact]
    public void Validator_accepts_dictionary_words_only()
    {
        var validator = new WordGuessContentValidator(Words);
        Assert.Equal("crane", validator.Validate("""{"word":" Crane "}""").ContentKey);
        Assert.NotNull(validator.Validate("""{"word":"abc"}""").Error);
        Assert.NotNull(validator.Validate("""{"word":"zzzzz"}""").Error);
    }
}

public class MiniCrosswordTests
{
    // C A T
    // A # O
    // B O X      across: 1 CAT, 3 BOX · down: 1 CAB, 2 TOX
    private const string Payload = """
        {"rows":["CAT","A#O","BOX"],"clues":{"across":{"1":"Pet","3":"Container"},"down":{"1":"Taxi","2":"Poison prefix"}}}
        """;

    [Fact]
    public void Validator_numbers_entries_and_requires_every_clue()
    {
        var validator = new MiniCrosswordContentValidator();
        var ok = validator.Validate(Payload);
        Assert.Null(ok.Error);
        Assert.Equal("CAT/A#O/BOX", ok.ContentKey);

        var missing = validator.Validate(Payload.Replace(""","3":"Container" """.Trim(), ""));
        Assert.Contains("Missing across", missing.Error);
        Assert.NotNull(validator.Validate("""{"rows":["CA","AB"],"clues":{"across":{},"down":{}}}""").Error);
    }

    [Fact]
    public void Game_hides_letters_and_verifies_the_grid()
    {
        var game = new MiniCrosswordGame(new FakeContent(FakeContent.Item("mini-crossword", "CAT/A#O/BOX", Payload)));
        var puzzle = game.Generate(1, 1);
        Assert.DoesNotContain("BOX", puzzle.PublicJson);
        Assert.Contains("Container", puzzle.PublicJson);

        Assert.Equal(PuzzleOutcome.Solved, game.Verify(puzzle, new { letters = "cata#obox" }).Outcome);
        Assert.Equal(PuzzleOutcome.Incorrect, game.Verify(puzzle, new { letters = "CATA#OBOY" }).Outcome);
        Assert.Equal(PuzzleOutcome.Incorrect, game.Verify(puzzle, new { letters = "CATA#OBO " }).Outcome);
        Assert.Equal(PuzzleOutcome.Invalid, game.Verify(puzzle, new { letters = "CAT" }).Outcome);
    }
}

public class WordHuntTests
{
    [Fact]
    public void Swipes_are_checked_scored_and_time_limited()
    {
        // Roll the board once, then build a dictionary holding the first row's 3-letter word and roll again (same seed, same board).
        var probe = new WordHuntGame(new WordDictionary(["zzz"])) { MinWordsOverride = 0 }.Generate(9, 1);
        var tiles = Node(probe.PublicJson)["tiles"]!.AsArray().Select(t => t!.GetValue<string>()).ToArray();
        var word = tiles[0] + tiles[1] + tiles[2];
        var game = new WordHuntGame(new WordDictionary([word, "zzz"])) { MinWordsOverride = 0 };
        var puzzle = game.Generate(9, 1);
        Assert.Equal(probe.PublicJson, puzzle.PublicJson);
        Assert.Contains(word, puzzle.SecretJson);

        var results = game.Play(puzzle,
        [
            new { path = new[] { 0, 1, 2 } },   // the word
            new { path = new[] { 0, 1, 2 } },   // again
            new { path = new[] { 0, 2, 1 } },   // 0→2 is not adjacent
        ]);
        Assert.True(Node(results[0].ResponseJson)["valid"]!.GetValue<bool>());
        Assert.Equal("repeat", Node(results[1].ResponseJson)["reason"]!.GetValue<string>());
        Assert.Equal("path", Node(results[2].ResponseJson)["reason"]!.GetValue<string>());

        var late = game.Play(puzzle, [new { path = new[] { 0, 1, 2 } }], TimeSpan.FromSeconds(200));
        Assert.Equal("time", Node(late[0].ResponseJson)["reason"]!.GetValue<string>());

        var verdict = game.Verify(puzzle, new { }, results[^1].StateJson);
        Assert.Equal(PuzzleOutcome.Solved, verdict.Outcome);
        Assert.Equal(1, Node(verdict.ResultJson!)["points"]!.GetValue<int>());
    }

    [Fact]
    public void Without_a_word_list_the_game_is_unavailable() =>
        Assert.Throws<PuzzleContentUnavailableException>(() => new WordHuntGame(WordDictionary.Empty).Generate(1, 1));

    [Theory]
    [InlineData("cat", 1)]
    [InlineData("crane", 2)]
    [InlineData("planet", 3)]
    [InlineData("players", 5)]
    [InlineData("crossword", 11)]
    public void Scores_by_length(string word, int points) => Assert.Equal(points, WordHuntGame.Points(word));
}
