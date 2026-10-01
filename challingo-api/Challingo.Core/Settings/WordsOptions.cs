namespace Challingo.Core.Settings;

/// <summary>Word list settings (env: Words__*).</summary>
public sealed class WordsOptions
{
    /// <summary>Plain text, one word per line; relative paths resolve from the API's content root.</summary>
    public string DictionaryPath { get; set; } = "Data/words/enable1.txt";
}
