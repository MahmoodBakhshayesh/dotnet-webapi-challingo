using System.Numerics;

namespace Challingo.Core.Puzzles.Games.Sudoku;

/// <summary>Bitmask backtracking solver: fills grids and counts solutions (stopping at a limit).</summary>
public static class SudokuSolver
{
    /// <summary>A complete valid grid, randomised by <paramref name="rng"/>. 0 = empty in all grids.</summary>
    public static int[] Fill(SudokuShape shape, Random rng)
    {
        var grid = new int[shape.Cells];
        var state = new State(shape, grid);
        if (!FillFrom(state, rng))
            throw new InvalidOperationException("Could not fill an empty grid.");
        return grid;
    }

    /// <summary>Number of solutions of <paramref name="grid"/>, counting no further than <paramref name="limit"/>.</summary>
    public static int CountSolutions(SudokuShape shape, int[] grid, int limit = 2)
    {
        var copy = (int[])grid.Clone();
        var state = new State(shape, copy);
        if (!state.Valid)
            return 0;
        var count = 0;
        Count(state, limit, ref count);
        return count;
    }

    private static bool FillFrom(State s, Random rng)
    {
        var cell = s.MostConstrainedEmpty(out var candidates);
        if (cell < 0)
            return true;

        var digits = Digits(candidates);
        for (var i = digits.Count - 1; i > 0; i--)
        {
            var j = rng.Next(i + 1);
            (digits[i], digits[j]) = (digits[j], digits[i]);
        }

        foreach (var d in digits)
        {
            s.Place(cell, d);
            if (FillFrom(s, rng))
                return true;
            s.Clear(cell, d);
        }
        return false;
    }

    private static void Count(State s, int limit, ref int count)
    {
        var cell = s.MostConstrainedEmpty(out var candidates);
        if (cell < 0)
        {
            count++;
            return;
        }

        foreach (var d in Digits(candidates))
        {
            s.Place(cell, d);
            Count(s, limit, ref count);
            s.Clear(cell, d);
            if (count >= limit)
                return;
        }
    }

    private static List<int> Digits(int mask)
    {
        var digits = new List<int>(BitOperations.PopCount((uint)mask));
        for (var d = 1; mask != 0; d++, mask >>= 1)
        {
            if ((mask & 1) != 0)
                digits.Add(d);
        }
        return digits;
    }

    private sealed class State
    {
        private readonly SudokuShape _shape;
        private readonly int[] _grid;
        private readonly int[] _rows, _cols, _boxes;
        private readonly int _all;

        public bool Valid { get; } = true;

        public State(SudokuShape shape, int[] grid)
        {
            _shape = shape;
            _grid = grid;
            _rows = new int[shape.Size];
            _cols = new int[shape.Size];
            _boxes = new int[shape.Size];
            _all = (1 << shape.Size) - 1;

            for (var i = 0; i < grid.Length; i++)
            {
                var d = grid[i];
                if (d == 0)
                    continue;
                var bit = 1 << (d - 1);
                int r = i / shape.Size, c = i % shape.Size, b = shape.Box(r, c);
                if (d < 1 || d > shape.Size || ((_rows[r] | _cols[c] | _boxes[b]) & bit) != 0)
                {
                    Valid = false;
                    return;
                }
                _rows[r] |= bit;
                _cols[c] |= bit;
                _boxes[b] |= bit;
            }
        }

        /// <summary>The empty cell with the fewest candidates (-1 when full); speeds search a lot on 9×9.</summary>
        public int MostConstrainedEmpty(out int candidates)
        {
            int best = -1, bestCount = int.MaxValue;
            candidates = 0;
            for (var i = 0; i < _grid.Length; i++)
            {
                if (_grid[i] != 0)
                    continue;
                int r = i / _shape.Size, c = i % _shape.Size;
                var mask = _all & ~(_rows[r] | _cols[c] | _boxes[_shape.Box(r, c)]);
                var n = BitOperations.PopCount((uint)mask);
                if (n < bestCount)
                {
                    best = i;
                    bestCount = n;
                    candidates = mask;
                    if (n <= 1)
                        break;
                }
            }
            return best;
        }

        public void Place(int cell, int d)
        {
            var bit = 1 << (d - 1);
            int r = cell / _shape.Size, c = cell % _shape.Size;
            _grid[cell] = d;
            _rows[r] |= bit;
            _cols[c] |= bit;
            _boxes[_shape.Box(r, c)] |= bit;
        }

        public void Clear(int cell, int d)
        {
            var bit = ~(1 << (d - 1));
            int r = cell / _shape.Size, c = cell % _shape.Size;
            _grid[cell] = 0;
            _rows[r] &= bit;
            _cols[c] &= bit;
            _boxes[_shape.Box(r, c)] &= bit;
        }
    }
}
