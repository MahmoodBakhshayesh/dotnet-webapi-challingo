namespace Challingo.Core.Puzzles.Games.Sudoku;

/// <summary>Grid geometry plus how many givens a difficulty leaves on the board.</summary>
public sealed record SudokuShape(int Size, int BoxRows, int BoxCols, int TargetGivens)
{
    public int Cells => Size * Size;

    /// <summary>1 = 6×6 (ranked rounds), 2–4 = 9×9 easy / medium / hard (daily puzzle).</summary>
    public static SudokuShape ForDifficulty(int difficulty) => difficulty switch
    {
        <= 1 => new SudokuShape(6, 2, 3, 14),
        2 => new SudokuShape(9, 3, 3, 36),
        3 => new SudokuShape(9, 3, 3, 30),
        _ => new SudokuShape(9, 3, 3, 26),
    };

    public int Box(int row, int col) => row / BoxRows * (Size / BoxCols) + col / BoxCols;
}
