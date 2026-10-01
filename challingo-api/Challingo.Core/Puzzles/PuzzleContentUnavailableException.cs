namespace Challingo.Core.Puzzles;

/// <summary>A content-based game (crossword, word lists) has nothing approved to build a puzzle from.</summary>
public sealed class PuzzleContentUnavailableException(string message) : Exception(message);
