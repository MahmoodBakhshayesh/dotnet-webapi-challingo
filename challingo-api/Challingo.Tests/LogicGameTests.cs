using System.Diagnostics;
using System.Text.Json.Nodes;
using Challingo.Core.Puzzles;
using Challingo.Core.Puzzles.Games.CodeBreaker;
using Challingo.Core.Puzzles.Games.Kakuro;
using Challingo.Core.Puzzles.Games.MineLogic;
using Challingo.Core.Puzzles.Games.NumberMerge;
using Challingo.Core.Puzzles.Games.Nonogram;
using Challingo.Core.Puzzles.Games.PathLink;
using Xunit;
using Xunit.Abstractions;
using static Challingo.Tests.PuzzleTestHelpers;

namespace Challingo.Tests;

public class GeneratorContractTests(ITestOutputHelper output)
{
    public static TheoryData<IPuzzleGame> Games => new()
    {
        new CodeBreakerGame(), new MineLogicGame(), new NumberMergeGame(),
        new PathLinkGame(), new KakuroGame(), new NonogramGame(),
    };

    [Theory]
    [MemberData(nameof(Games))]
    public void Same_seed_same_puzzle_and_every_difficulty_generates(IPuzzleGame game)
    {
        Assert.Equal(game.Generate(11, 2).PublicJson, game.Generate(11, 2).PublicJson);
        for (var difficulty = 1; difficulty <= 4; difficulty++)
        {
            var watch = Stopwatch.StartNew();
            for (var seed = 1; seed <= 5; seed++)
                game.Generate(seed * 7919, difficulty);
            output.WriteLine($"{game.Key} d{difficulty}: {watch.ElapsedMilliseconds / 5} ms per puzzle");
        }
    }
}

public class CodeBreakerTests
{
    private readonly CodeBreakerGame _game = new();

    [Theory]
    [InlineData(new[] { 1, 2, 3, 4 }, new[] { 1, 2, 3, 4 }, 4, 0)]
    [InlineData(new[] { 1, 2, 3, 4 }, new[] { 4, 3, 2, 1 }, 0, 4)]
    [InlineData(new[] { 1, 1, 2, 2 }, new[] { 1, 2, 1, 5 }, 1, 2)]
    [InlineData(new[] { 0, 0, 0, 1 }, new[] { 0, 1, 1, 1 }, 2, 0)]
    public void Scores_exact_and_partial(int[] code, int[] guess, int exact, int partial) =>
        Assert.Equal((exact, partial), CodeBreakerGame.Score(code, guess, 6));

    [Fact]
    public void Solving_ends_the_attempt_and_reveals_nothing_before()
    {
        var puzzle = _game.Generate(5, 1);
        var code = Ints(puzzle.SecretJson, "code");
        var wrong = code.Select(c => (c + 1) % 6).ToArray();

        var results = _game.Play(puzzle, [new { guess = wrong }, new { guess = code }]);
        Assert.Null(results[0].Outcome);
        Assert.Null(Node(results[0].ResponseJson)["code"]);
        Assert.Equal(PuzzleOutcome.Solved, results[1].Outcome);
        Assert.Equal(2, Node(results[1].ResultJson!)["guesses"]!.GetValue<int>());
    }

    [Fact]
    public void Running_out_of_guesses_fails_and_rejects_bad_guesses()
    {
        var puzzle = _game.Generate(5, 2); // 8 guesses
        var code = Ints(puzzle.SecretJson, "code");
        var wrong = new { guess = code.Select(c => (c + 1) % 6).ToArray() };

        var results = _game.Play(puzzle, Enumerable.Repeat<object>(wrong, 8));
        Assert.Equal(PuzzleOutcome.Failed, results[^1].Outcome);
        Assert.NotNull(Node(results[^1].ResponseJson)["code"]);
        Assert.NotNull(_game.Play(puzzle, [new { guess = new[] { 9, 9, 9, 9 } }])[0].Error);
    }
}

public class MineLogicTests
{
    private readonly MineLogicGame _game = new();

    [Fact]
    public void Revealing_every_safe_cell_solves_and_a_mine_fails()
    {
        var puzzle = _game.Generate(21, 1);
        var mines = Ints(puzzle.SecretJson, "mines").ToHashSet();
        var opening = Node(puzzle.PublicJson)["opening"]!.AsArray().Select(c => c!["i"]!.GetValue<int>()).ToHashSet();
        Assert.DoesNotContain(opening, mines.Contains);

        var safe = Enumerable.Range(0, 64).Where(i => !mines.Contains(i) && !opening.Contains(i));
        var revealed = new HashSet<int>(opening);
        var moves = new List<object>();
        foreach (var cell in safe)
            moves.Add(new { reveal = cell });

        // Replay but skip cells already opened by an earlier flood.
        string? state = null;
        PuzzleMoveResult? last = null;
        foreach (var cell in safe)
        {
            if (revealed.Contains(cell))
                continue;
            last = _game.ApplyMove(new PuzzleMove(puzzle.PublicJson, puzzle.SecretJson, state,
                $"{{\"reveal\":{cell}}}", TimeSpan.FromSeconds(10)));
            Assert.Null(last.Error);
            state = last.StateJson;
            foreach (var r in Node(last.ResponseJson)["revealed"]!.AsArray())
                revealed.Add(r!["i"]!.GetValue<int>());
        }
        Assert.Equal(PuzzleOutcome.Solved, last!.Outcome);

        var boom = _game.Play(puzzle, [new { reveal = mines.First() }]);
        Assert.Equal(PuzzleOutcome.Failed, boom[0].Outcome);
    }
}

public class NumberMergeTests
{
    private readonly NumberMergeGame _game = new();

    [Fact]
    public void Mulberry32_matches_reference_values()
    {
        // Reference values from the JavaScript mulberry32 (Math.imul, >>> 0) with seed 1, run in Node.
        var rng = new Mulberry32(1);
        Assert.Equal(2693262067u, rng.Next());
        Assert.Equal(11749833u, rng.Next());
        Assert.Equal(2265367787u, rng.Next());
    }

    [Fact]
    public void Replays_moves_and_reaches_target_with_a_simple_strategy()
    {
        var puzzle = _game.Generate(3, 1); // target 128
        var seed = Node(puzzle.PublicJson)["seed"]!.GetValue<uint>();

        // Corner strategy: cycle D,L and fall back to R/U when stuck — reaches 128 reliably.
        var board = new MergeBoard(4, new Mulberry32(seed));
        var moves = new System.Text.StringBuilder();
        for (var i = 0; i < 4000 && board.MaxTile < 128; i++)
        {
            foreach (var m in new[] { 'D', 'L', 'R', 'U' })
            {
                if (board.Move(m))
                {
                    moves.Append(m);
                    break;
                }
            }
        }
        Assert.True(board.MaxTile >= 128, "strategy should reach 128");

        var verdict = _game.Verify(puzzle, new { moves = moves.ToString() });
        Assert.Equal(PuzzleOutcome.Solved, verdict.Outcome);
        Assert.Equal(PuzzleOutcome.Incorrect, _game.Verify(puzzle, new { moves = "DL" }).Outcome);
        Assert.Equal(PuzzleOutcome.Invalid, _game.Verify(puzzle, new { moves = "DLX" }).Outcome);
    }
}

public class PathLinkTests
{
    private readonly PathLinkGame _game = new();

    [Theory]
    [InlineData(1)]
    [InlineData(4)]
    public void Stored_solution_verifies_and_partial_or_broken_paths_do_not(int difficulty)
    {
        for (var seed = 1; seed <= 10; seed++)
        {
            var puzzle = _game.Generate(seed, difficulty);
            var paths = Node(puzzle.SecretJson)["paths"]!.AsArray()
                .Select(p => p!.AsArray().Select(c => c!.GetValue<int>()).ToArray()).ToArray();
            Assert.Equal(PuzzleOutcome.Solved, _game.Verify(puzzle, new { paths }).Outcome);

            // Reversed direction is fine.
            var reversed = paths.Select((p, k) => k == 0 ? p.Reverse().ToArray() : p).ToArray();
            Assert.Equal(PuzzleOutcome.Solved, _game.Verify(puzzle, new { paths = reversed }).Outcome);
        }

        var first = _game.Generate(1, difficulty);
        var dots = Node(first.PublicJson)["dots"]!.AsArray();
        var jump = dots.Select(d => new[] { d![0]!.GetValue<int>(), d[1]!.GetValue<int>() }).ToArray();
        Assert.Equal(PuzzleOutcome.Invalid, _game.Verify(first, new { paths = jump }).Outcome);
    }
}

public class KakuroTests
{
    private readonly KakuroGame _game = new();

    [Fact]
    public void Solver_counts_a_known_unique_and_a_known_ambiguous_grid()
    {
        // 3x3 board, white 2x2 in the corner: a b / c d.
        var white = new bool[9];
        white[4] = white[5] = white[7] = white[8] = true;
        var runs = KakuroRunsForTests.Find(3, white);
        // Unique: a=1,b=2,c=3,d=1 → across 3 and 4, down 4 and 3.
        Assert.Equal(1, KakuroSolverForTests.Count(3, white, runs, SumsFor(runs, new[] { 0, 0, 0, 0, 1, 2, 0, 3, 1 })));
        // Ambiguous: all runs sum 3 → a,b,c,d in {1,2} with a=d, b=c: two solutions.
        Assert.Equal(2, KakuroSolverForTests.Count(3, white, runs, SumsFor(runs, new[] { 0, 0, 0, 0, 1, 2, 0, 2, 1 })));
    }

    private static int[] SumsFor(IReadOnlyList<(int ClueCell, bool Across, int[] Cells)> runs, int[] values) =>
        runs.Select(r => r.Cells.Sum(i => values[i])).ToArray();

    [Fact]
    public void Solution_verifies_and_clues_match_it()
    {
        for (var seed = 1; seed <= 5; seed++)
        {
            var puzzle = _game.Generate(seed, 2);
            var solution = Ints(puzzle.SecretJson, "solution");
            Assert.Equal(PuzzleOutcome.Solved, _game.Verify(puzzle, new { cells = solution }).Outcome);

            var grid = Node(puzzle.PublicJson)["grid"]!.AsArray();
            var size = Node(puzzle.PublicJson)["size"]!.GetValue<int>();
            for (var i = 0; i < grid.Count; i++)
            {
                if (grid[i]!["a"] is JsonNode a)
                {
                    var sum = 0;
                    for (var c = i + 1; c % size != 0 && grid[c]!["t"]!.GetValue<string>() == "w"; c++)
                        sum += solution[c];
                    Assert.Equal(a.GetValue<int>(), sum);
                }
            }

            var wrong = (int[])solution.Clone();
            var w = Array.FindIndex(wrong, v => v != 0);
            wrong[w] = wrong[w] % 9 + 1;
            Assert.Equal(PuzzleOutcome.Incorrect, _game.Verify(puzzle, new { cells = wrong }).Outcome);
        }
    }
}

public class NonogramTests
{
    private readonly NonogramGame _game = new();

    [Theory]
    [InlineData(new[] { 0, 0, 0 }, new[] { 0 })]
    [InlineData(new[] { 1, 1, 0, 1 }, new[] { 2, 1 })]
    [InlineData(new[] { 1, 1, 1, 1 }, new[] { 4 })]
    public void Clues_are_run_lengths(int[] line, int[] clue) => Assert.Equal(clue, NonogramGame.Clue(line));

    [Fact]
    public void Solver_spots_an_ambiguous_puzzle()
    {
        // A 2x2 with one cell per row and column: both diagonals fit.
        int[][] ones = [[1], [1]];
        Assert.Equal(2, Challingo.Core.Puzzles.Games.Nonogram.NonogramSolver.CountSolutions(2, 2, ones, ones, 5));
        // Full row on top, empty below: only one way.
        Assert.Equal(1, Challingo.Core.Puzzles.Games.Nonogram.NonogramSolver.CountSolutions(2, 2, [[2], [0]], [[1], [1]], 5));
    }

    [Fact]
    public void Solution_verifies_and_a_flipped_cell_does_not()
    {
        for (var seed = 1; seed <= 5; seed++)
        {
            var puzzle = _game.Generate(seed, 3);
            var cells = Ints(puzzle.SecretJson, "cells");
            Assert.Equal(PuzzleOutcome.Solved, _game.Verify(puzzle, new { cells }).Outcome);
            cells[seed] ^= 1;
            Assert.Equal(PuzzleOutcome.Incorrect, _game.Verify(puzzle, new { cells }).Outcome);
        }
    }
}

internal static class KakuroRunsForTests
{
    public static List<(int ClueCell, bool Across, int[] Cells)> Find(int size, bool[] white) =>
        Challingo.Core.Puzzles.Games.Kakuro.KakuroRuns.Find(size, white).Select(r => (r.ClueCell, r.Across, r.Cells)).ToList();
}

internal static class KakuroSolverForTests
{
    public static int Count(int size, bool[] white, List<(int ClueCell, bool Across, int[] Cells)> runs, int[] sums) =>
        Challingo.Core.Puzzles.Games.Kakuro.KakuroSolver.CountSolutions(size, white,
            runs.Select(r => new Challingo.Core.Puzzles.Games.Kakuro.KakuroRun(r.ClueCell, r.Across, r.Cells)).ToList(), sums, 5);
}
