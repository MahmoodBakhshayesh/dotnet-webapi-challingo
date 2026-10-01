using System.Security.Cryptography;
using System.Text;

namespace Challingo.Core.Services;

public static class OtpHash
{
    public static string Hash(string code) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(code)));
}
