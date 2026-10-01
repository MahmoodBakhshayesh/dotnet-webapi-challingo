namespace Challingo.Core.Puzzles;

public interface IPuzzleGameRegistry
{
    IReadOnlyCollection<string> Keys { get; }
    IPuzzleGame? Find(string key);
}

/// <summary>All registered <see cref="IPuzzleGame"/>s, looked up by key (case-insensitive).</summary>
public sealed class PuzzleGameRegistry(IEnumerable<IPuzzleGame> games) : IPuzzleGameRegistry
{
    private readonly Dictionary<string, IPuzzleGame> _games =
        games.ToDictionary(g => g.Key, StringComparer.OrdinalIgnoreCase);

    public IReadOnlyCollection<string> Keys => _games.Keys;

    public IPuzzleGame? Find(string key) => _games.GetValueOrDefault(key);
}
