namespace Challingo.Core.Puzzles.Words;

/// <summary>The English word list used to check guesses and find words on letter grids.</summary>
public interface IWordDictionary
{
    /// <summary>False until a word list is loaded (see <c>Words:DictionaryPath</c>).</summary>
    bool IsLoaded { get; }
    int Count { get; }
    bool Contains(string word);

    /// <summary>True when some word starts with <paramref name="prefix"/> (used to prune letter-grid walks).</summary>
    bool HasPrefix(string prefix);
}

/// <summary>In-memory dictionary of lowercase a–z words, 3 to 16 letters.</summary>
public sealed class WordDictionary : IWordDictionary
{
    public const int MinLength = 3;
    public const int MaxLength = 16;

    private readonly HashSet<string> _words;

    // Sorted copy for prefix lookups: a few MB, where a 26-way trie over ~170k words would take hundreds.
    private readonly string[] _sorted;

    public WordDictionary(IEnumerable<string> words)
    {
        _words = words.Select(Normalize).OfType<string>().ToHashSet(StringComparer.Ordinal);
        _sorted = _words.Order(StringComparer.Ordinal).ToArray();
    }

    public static WordDictionary Empty { get; } = new([]);

    public bool IsLoaded => _words.Count > 0;
    public int Count => _words.Count;

    public bool Contains(string word) => Normalize(word) is { } w && _words.Contains(w);

    public bool HasPrefix(string prefix)
    {
        var i = Array.BinarySearch(_sorted, prefix, StringComparer.Ordinal);
        if (i >= 0)
            return true;
        i = ~i;
        return i < _sorted.Length && _sorted[i].StartsWith(prefix, StringComparison.Ordinal);
    }

    /// <summary>Lowercase a–z word of allowed length, or null.</summary>
    public static string? Normalize(string? word)
    {
        var w = word?.Trim().ToLowerInvariant();
        return w is { Length: >= MinLength and <= MaxLength } && w.All(c => c is >= 'a' and <= 'z') ? w : null;
    }
}
