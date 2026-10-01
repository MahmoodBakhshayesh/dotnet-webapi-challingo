using Microsoft.Extensions.Logging;
using Challingo.Core.Puzzles.Words;

namespace Challingo.Infrastructure.Words;

public static class FileWordDictionary
{
    /// <summary>Loads one word per line; a missing file gives an empty dictionary (word games then report unavailable).</summary>
    public static WordDictionary Load(string path, ILogger logger)
    {
        if (!File.Exists(path))
        {
            logger.LogWarning("Word list not found at {Path}; Word Hunt and Word Guess are unavailable until it is added.", path);
            return WordDictionary.Empty;
        }
        var dictionary = new WordDictionary(File.ReadLines(path));
        logger.LogInformation("Loaded {Count} words from {Path}", dictionary.Count, path);
        return dictionary;
    }
}
