using System.Text.Json;
using Microsoft.Extensions.Options;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Players;
using Challingo.Core.Puzzles;
using Challingo.Core.Puzzles.Games.Sudoku;
using Challingo.Core.Services;
using Challingo.Core.Settings;
using Xunit;

namespace Challingo.Tests;

public class SudokuGameTests
{
    private readonly SudokuGame _game = new();

    [Theory]
    [InlineData(1, 6)]
    [InlineData(2, 9)]
    [InlineData(4, 9)]
    public void Generates_unique_solution_puzzles(int difficulty, int size)
    {
        for (var seed = 1; seed <= 20; seed++)
        {
            var puzzle = _game.Generate(seed, difficulty);
            var givens = Read(puzzle.PublicJson, "givens");
            var shape = SudokuShape.ForDifficulty(difficulty);

            Assert.Equal(size * size, givens.Length);
            Assert.Equal(1, SudokuSolver.CountSolutions(shape, givens));
        }
    }

    [Fact]
    public void Same_seed_gives_same_puzzle()
    {
        Assert.Equal(_game.Generate(42, 2).PublicJson, _game.Generate(42, 2).PublicJson);
        Assert.NotEqual(_game.Generate(42, 2).PublicJson, _game.Generate(43, 2).PublicJson);
    }

    [Fact]
    public void Verify_accepts_solution_and_rejects_wrong_or_tampered_grids()
    {
        var puzzle = _game.Generate(7, 1);
        var solution = Read(puzzle.SecretJson, "solution");
        var givens = Read(puzzle.PublicJson, "givens");

        Assert.Equal(PuzzleOutcome.Solved, Verify(puzzle, solution).Outcome);

        var wrong = (int[])solution.Clone();
        var free = Array.FindIndex(givens, g => g == 0);
        wrong[free] = wrong[free] % 6 + 1;
        Assert.Equal(PuzzleOutcome.Incorrect, Verify(puzzle, wrong).Outcome);

        var tampered = (int[])solution.Clone();
        var given = Array.FindIndex(givens, g => g != 0);
        tampered[given] = tampered[given] % 6 + 1;
        Assert.Equal(PuzzleOutcome.Invalid, Verify(puzzle, tampered).Outcome);
        Assert.Equal(PuzzleOutcome.Invalid, _game.Verify(puzzle, new { cells = new[] { 1, 2 } }).Outcome);
    }

    private PuzzleVerdict Verify(GeneratedPuzzle puzzle, int[] cells) => _game.Verify(puzzle, new { cells });

    private static int[] Read(string json, string property) =>
        JsonDocument.Parse(json).RootElement.GetProperty(property).EnumerateArray().Select(e => e.GetInt32()).ToArray();
}

public class PlayerTimeZoneTests
{
    [Theory]
    [InlineData("Europe/Berlin", "Europe/Berlin", "DE")]
    [InlineData("Asia/Calcutta", "Asia/Kolkata", "IN")]
    [InlineData("America/New_York", "America/New_York", "US")]
    [InlineData("Asia/Tehran", "Asia/Tehran", "IR")]
    public void Normalizes_zone_and_finds_country(string input, string canonical, string country)
    {
        Assert.True(PlayerTimeZones.TryNormalize(input, out var zone));
        Assert.Equal(canonical, zone);
        Assert.Equal(country, PlayerTimeZones.CountryFor(zone));
    }

    [Fact]
    public void Rejects_unknown_zone_and_utc_has_no_country()
    {
        Assert.False(PlayerTimeZones.TryNormalize("Mars/Olympus", out _));
        Assert.True(PlayerTimeZones.TryNormalize("UTC", out var utc));
        Assert.Null(PlayerTimeZones.CountryFor(utc));
    }

    [Fact]
    public void Local_date_follows_the_zone()
    {
        var utc = new DateTime(2026, 10, 1, 22, 30, 0, DateTimeKind.Utc);
        Assert.Equal(new DateOnly(2026, 10, 2), PlayerTimeZones.LocalDate("Asia/Tokyo", utc));
        Assert.Equal(new DateOnly(2026, 10, 1), PlayerTimeZones.LocalDate("America/New_York", utc));
    }

    [Fact]
    public void Zone_change_applies_from_next_local_midnight_of_the_old_zone()
    {
        var changedAt = new DateTime(2026, 10, 1, 10, 0, 0, DateTimeKind.Utc);
        var profile = new PlayerProfile
        {
            TimeZoneId = "Asia/Tokyo",
            PreviousTimeZoneId = "Europe/London",
            TimeZoneChangedAtUtc = changedAt,
        };

        // London midnight (BST, UTC+1) is 23:00 UTC.
        Assert.Equal("Europe/London", PlayerProfileRules.EffectiveTimeZone(profile, changedAt.AddHours(12)));
        Assert.Equal("Asia/Tokyo", PlayerProfileRules.EffectiveTimeZone(profile, changedAt.AddHours(13)));
    }

    [Theory]
    [InlineData("Sara", true)]
    [InlineData("Ali_99", true)]
    [InlineData("ab", false)]
    [InlineData("this name is far too long", false)]
    [InlineData("<script>", false)]
    public void Validates_display_names(string name, bool valid) =>
        Assert.Equal(valid, PlayerProfileRules.IsValidDisplayName(name));
}

public class AttemptTokenServiceTests
{
    private readonly AttemptTokenService _tokens = new(
        Options.Create(new PuzzleOptions()),
        Options.Create(new JwtAuthOptions { Issuer = "test", Audience = "test", Key = "unit-test-key-0123456789-abcdefghijklmnop" }));

    [Fact]
    public void Token_is_bound_to_attempt_and_user()
    {
        Guid attempt = Guid.NewGuid(), user = Guid.NewGuid();
        var token = _tokens.Create(attempt, user);

        Assert.True(_tokens.IsValid(token, attempt, user));
        Assert.False(_tokens.IsValid(token, Guid.NewGuid(), user));
        Assert.False(_tokens.IsValid(token, attempt, Guid.NewGuid()));
        Assert.False(_tokens.IsValid("not-a-token!", attempt, user));
        Assert.False(_tokens.IsValid(null, attempt, user));
    }
}
