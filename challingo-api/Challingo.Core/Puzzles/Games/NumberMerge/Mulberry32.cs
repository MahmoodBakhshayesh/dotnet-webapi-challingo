namespace Challingo.Core.Puzzles.Games.NumberMerge;

/// <summary>
/// mulberry32 PRNG. The app runs the same algorithm so both sides spawn identical tiles from the shared seed:
/// <code>
/// a += 0x6D2B79F5; t = (a ^ (a &gt;&gt;&gt; 15)) * (1 | a); t = (t + ((t ^ (t &gt;&gt;&gt; 7)) * (61 | t))) ^ t; return t ^ (t &gt;&gt;&gt; 14)
/// </code>
/// with every operation on unsigned 32-bit integers (in Dart: mask with <c>0xFFFFFFFF</c> after each multiply/add).
/// </summary>
public sealed class Mulberry32(uint seed)
{
    private uint _a = seed;

    public uint Next()
    {
        unchecked
        {
            _a += 0x6D2B79F5;
            var t = (_a ^ (_a >> 15)) * (1 | _a);
            t = (t + ((t ^ (t >> 7)) * (61 | t))) ^ t;
            return t ^ (t >> 14);
        }
    }

    /// <summary>Uniform-enough value in [0, n) — <c>next() % n</c>, matching the app.</summary>
    public int Below(int n) => (int)(Next() % (uint)n);
}
