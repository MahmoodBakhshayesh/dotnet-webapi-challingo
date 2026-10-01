using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Core.Services;

public sealed class AttemptTokenService(IOptions<PuzzleOptions> puzzleOptions, IOptions<JwtAuthOptions> jwtOptions)
    : IAttemptTokenService
{
    private readonly byte[] _key = SHA256.HashData(Encoding.UTF8.GetBytes(
        string.IsNullOrWhiteSpace(puzzleOptions.Value.AttemptTokenKey)
            ? "attempt-token:" + jwtOptions.Value.Key
            : puzzleOptions.Value.AttemptTokenKey));

    public string Create(Guid attemptId, Guid userId) => Base64Url(Sign(attemptId, userId));

    public bool IsValid(string? token, Guid attemptId, Guid userId)
    {
        if (string.IsNullOrWhiteSpace(token))
            return false;
        try
        {
            var given = Convert.FromBase64String(PadBase64(token.Replace('-', '+').Replace('_', '/')));
            return CryptographicOperations.FixedTimeEquals(given, Sign(attemptId, userId));
        }
        catch (FormatException)
        {
            return false;
        }
    }

    private byte[] Sign(Guid attemptId, Guid userId) =>
        HMACSHA256.HashData(_key, Encoding.UTF8.GetBytes($"{attemptId:N}:{userId:N}"));

    private static string Base64Url(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static string PadBase64(string s) => s.PadRight(s.Length + (4 - s.Length % 4) % 4, '=');
}
