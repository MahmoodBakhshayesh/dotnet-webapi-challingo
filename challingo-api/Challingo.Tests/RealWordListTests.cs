using System.Diagnostics;
using Challingo.Core.Puzzles.Games.WordHunt;
using Challingo.Core.Puzzles.Words;
using Xunit;
using Xunit.Abstractions;
using static Challingo.Tests.PuzzleTestHelpers;

namespace Challingo.Tests;

/// <summary>Runs against the shipped word list (Challingo.Api/Data/words/enable1.txt).</summary>
public class RealWordListTests(ITestOutputHelper output)
{
    private static readonly string ListPath = Path.GetFullPath(Path.Combine(
        AppContext.BaseDirectory, "../../../../Challingo.Api/Data/words/enable1.txt"));

    [Fact]
    public void Word_hunt_boards_from_the_real_list()
    {
        Assert.True(File.Exists(ListPath), $"word list missing at {ListPath}");
        var load = Stopwatch.StartNew();
        var dictionary = new WordDictionary(File.ReadLines(ListPath));
        output.WriteLine($"loaded {dictionary.Count} words in {load.ElapsedMilliseconds} ms");
        Assert.True(dictionary.Contains("crane") && dictionary.HasPrefix("cran") && !dictionary.HasPrefix("xqz"));

        var game = new WordHuntGame(dictionary);
        foreach (var difficulty in new[] { 1, 3 })
        {
            var watch = Stopwatch.StartNew();
            var puzzle = game.Generate(42, difficulty);
            var words = Node(puzzle.SecretJson)["words"]!.AsArray().Count;
            var tiles = string.Join(" ", Node(puzzle.PublicJson)["tiles"]!.AsArray().Select(t => t!.GetValue<string>()));
            output.WriteLine($"d{difficulty}: {words} words in {watch.ElapsedMilliseconds} ms — {tiles}");
            Assert.True(words >= 40);
        }
    }
}
