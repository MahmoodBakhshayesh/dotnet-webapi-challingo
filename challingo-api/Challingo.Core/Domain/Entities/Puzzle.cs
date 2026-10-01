namespace Challingo.Core.Domain.Entities;

/// <summary>A generated puzzle. <see cref="SecretJson"/> (the solution) never leaves the server.</summary>
public class Puzzle : BaseEntity
{
    public string GameKey { get; set; } = "";
    public int Seed { get; set; }
    public int Difficulty { get; set; }
    public int GeneratorVersion { get; set; }
    public string PublicJson { get; set; } = "{}";
    public string SecretJson { get; set; } = "{}";
}
